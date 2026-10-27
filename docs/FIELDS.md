FIRESTORE FIELD REFERENCE (single source of truth; keep seed, repositories and rules in sync with this)
 
users/{uid}                      role ('supervisor'|'pm'), name, siteId (supervisors only)
sites/{siteId}                   name, lastEntryAt (Timestamp)
sites/{siteId}/workers/{id}      name, trade, workerCode, active (bool)
sites/{siteId}/attendance/{siteId_workerId_yyyymmdd}
                                 workerId, status ('present'|'absent'|'half'), dateKey ('yyyy-MM-dd'),
                                 updatedAt (Timestamp, client time), createdBy (uid)
sites/{siteId}/materials/{id}    name, unit, openingStock, currentStock, lowStockThreshold
sites/{siteId}/materialLogs/{id} materialId, materialName, qtyUsed, remainingAfter, dateKey,
                                 createdAt (Timestamp, client time), createdBy (uid)
sites/{siteId}/incidents/{id}    severity ('minor'|'moderate'|'high'|'critical'), description (>= 10 chars),
                                 occurredAt (Timestamp, client time), createdBy (uid)
 
Rules of thumb: dates are filtered with the dateKey STRING (sortable, no timezone bugs); event times are
client Timestamps (never serverTimestamp, it is null offline); no composite indexes needed (avoid
combining a range filter with orderBy on a different field).
