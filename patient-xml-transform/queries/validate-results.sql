-- Validation queries for the BYOC lab.
-- Run them in Data 360 -> Query Editor, in the dataspace that holds the DLOs (default).
-- They return counts and IDs only, never patient details, so they are safe to share.

-- 1. The source should hold 4 clinic batches.
SELECT COUNT(*) AS batches
FROM "Patients_Raw_XML__dll";

-- 2. After the transform runs, the target should hold 12 patients (one per <Patient>).
SELECT COUNT(*) AS patients
FROM "Patients_Enriched__dll";

-- 3. COVID flag split. Expected: Yes = 5, No = 7.
SELECT "has_covid_vaccine__c", COUNT(*) AS patients
FROM "Patients_Enriched__dll"
GROUP BY "has_covid_vaccine__c"
ORDER BY "has_covid_vaccine__c";

-- 4. Spot-check the derived fields by ID. age__c depends on today's date.
SELECT "patient_id__c", "age__c", "most_recent_vaccination_date__c", "has_covid_vaccine__c"
FROM "Patients_Enriched__dll"
ORDER BY "patient_id__c";

-- 5. Latest log lines for the transform (newest first).
--    Replace Patient_Data_Transformer if you deployed with a different --name.
SELECT "Timestamp__c", "Message__c"
FROM "DataCustomCodeLogs__dll"
WHERE "DataCustomCodeName__c" = 'Patient_Data_Transformer'
ORDER BY "Timestamp__c" DESC
LIMIT 100;
