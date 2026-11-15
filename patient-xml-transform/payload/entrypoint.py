from pyspark.sql.functions import col, to_date
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    IntegerType,
)
import xml.etree.ElementTree as ET
from datetime import date, datetime

from datacustomcode.client import Client
from datacustomcode.io.writer.base import WriteMode


SOURCE_DLO = "Patients_Raw_XML__dll"
TARGET_DLO = "Patients_Enriched__dll"


VACCINE_CORRECTIONS = {
    "cominarty": "Comirnaty",
    "cominaty": "Comirnaty",
    "comirnaty": "Comirnaty",
    "jansenn": "Janssen",
    "janssen": "Janssen",
    "hpv": "HPV Vaccine",
    "hpv vaccine": "HPV Vaccine",
    "hp vaccinne": "HPV Vaccine",
    "covishield": "Covishield",
    "covaxin": "Covaxin",
    "moderna": "Moderna",
    "pfizer": "Pfizer",
    "spikevax": "Spikevax",
}


def standardize_vaccine_name(raw_name: str) -> str:
    if not raw_name:
        return ""
    key = raw_name.strip().lower()
    if key in VACCINE_CORRECTIONS:
        return VACCINE_CORRECTIONS[key]
    return raw_name.strip().title()


def compute_age(dob_str: str):
    """Derive age in whole years from an ISO date-of-birth string."""
    if not dob_str:
        return None
    try:
        dob = datetime.strptime(dob_str.strip(), "%Y-%m-%d").date()
    except Exception:
        return None
    today = date.today()
    return today.year - dob.year - (
        (today.month, today.day) < (dob.month, dob.day)
    )


def parse_patients(xml_str: str):
    """Parse one raw XML blob into a list of flat patient dicts."""
    results = []
    if not xml_str:
        return results

    try:
        root = ET.fromstring(xml_str)
    except Exception:
        return results

    for patient in root.findall(".//Patient"):
        name = (patient.findtext("Name") or "").strip()
        patient_id = (patient.findtext("PatientId") or "").strip()
        dob = (patient.findtext("DateOfBirth") or "").strip()

        vaccines, dates = [], []
        for vacc in patient.findall(".//Vaccination"):
            vname = (vacc.findtext("Vaccine") or "").strip()
            vdate = (vacc.findtext("Date") or "").strip()
            if vname:
                vaccines.append(standardize_vaccine_name(vname))
            if vdate:
                dates.append(vdate)

        # Parse the various date formats and keep the most recent shot.
        latest_date_iso = ""
        parsed_dates = []
        for d in dates:
            for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%Y/%m/%d", "%d-%m-%Y", "%d-%b-%Y"):
                try:
                    parsed_dates.append(datetime.strptime(d.strip(), fmt))
                    break
                except Exception:
                    continue
        if parsed_dates:
            latest_date_iso = max(parsed_dates).strftime("%Y-%m-%d")

        has_covid = any("covid" in v.lower() for v in vaccines)

        results.append({
            "patient_id__c": patient_id or None,
            "name__c": name or None,
            "age__c": compute_age(dob),
            "vaccines_received__c": ", ".join(vaccines) if vaccines else None,
            "most_recent_vaccination_date__c": latest_date_iso or None,
            "has_covid_vaccine__c": "Yes" if has_covid else "No",
        })

    return results


def main():
    client = Client()

    df = client.read_dlo(SOURCE_DLO)
    spark = df.sparkSession

    # Parse each XML blob on the driver with plain Python (no UDF), flattening
    # every clinic batch into one record per patient.
    output_rows = []
    for row in df.select("rawxml__c").collect():
        output_rows.extend(parse_patients(row["rawxml__c"]))

    if not output_rows:
        return

    # Columns match the Patients_Enriched__dll target DLO schema.
    schema = StructType([
        StructField("patient_id__c", StringType(), True),
        StructField("name__c", StringType(), True),
        StructField("age__c", IntegerType(), True),
        StructField("vaccines_received__c", StringType(), True),
        StructField("most_recent_vaccination_date__c", StringType(), True),
        StructField("has_covid_vaccine__c", StringType(), True),
    ])

    df_parsed = spark.createDataFrame(output_rows, schema=schema)

    df_parsed = df_parsed.withColumn(
        "most_recent_vaccination_date__c",
        to_date(col("most_recent_vaccination_date__c"), "yyyy-MM-dd"),
    )

    client.write_to_dlo(TARGET_DLO, df_parsed, write_mode=WriteMode.OVERWRITE)


if __name__ == "__main__":
    main()
