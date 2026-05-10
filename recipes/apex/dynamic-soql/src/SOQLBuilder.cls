/**
 * SOQLBuilder - Type-safe dynamic SOQL construction with FLS enforcement.
 *
 * Usage:
 *   String query = new SOQLBuilder()
 *       .selectFields(new List<String>{'Name', 'Email', 'Phone'})
 *       .fromObject('Contact')
 *       .whereCondition('AccountId', '=', accountId)
 *       .whereCondition('CreatedDate', '>', startDate)
 *       .orderBy('Name', 'ASC')
 *       .limitTo(50)
 *       .enforceFLS(true)
 *       .build();
 *
 * @author  Sandip Patel
 */
public class SOQLBuilder {

    private List<String> fields = new List<String>();
    private String objectName;
    private List<String> conditions = new List<String>();
    private String orderField;
    private String orderDirection = 'ASC';
    private Integer recordLimit;
    private Integer recordOffset;
    private Boolean flsEnforced = true;

    public SOQLBuilder selectFields(List<String> fieldNames) {
        this.fields.addAll(fieldNames);
        return this;
    }

    public SOQLBuilder selectField(String fieldName) {
        this.fields.add(fieldName);
        return this;
    }

    public SOQLBuilder fromObject(String objectName) {
        this.objectName = objectName;
        return this;
    }

    public SOQLBuilder whereCondition(String field, String operator, Object value) {
        String formattedValue = formatValue(value);
        this.conditions.add(field + ' ' + operator + ' ' + formattedValue);
        return this;
    }

    public SOQLBuilder whereIn(String field, Set<Id> ids) {
        List<String> idStrings = new List<String>();
        for (Id i : ids) {
            idStrings.add('\'' + String.escapeSingleQuotes(String.valueOf(i)) + '\'');
        }
        this.conditions.add(field + ' IN (' + String.join(idStrings, ',') + ')');
        return this;
    }

    public SOQLBuilder whereRaw(String rawCondition) {
        this.conditions.add(rawCondition);
        return this;
    }

    public SOQLBuilder orderBy(String field, String direction) {
        this.orderField = field;
        this.orderDirection = direction;
        return this;
    }

    public SOQLBuilder limitTo(Integer lim) {
        this.recordLimit = lim;
        return this;
    }

    public SOQLBuilder offsetBy(Integer off) {
        this.recordOffset = off;
        return this;
    }

    public SOQLBuilder enforceFLS(Boolean enforce) {
        this.flsEnforced = enforce;
        return this;
    }

    public String build() {
        if (this.objectName == null) {
            throw new SOQLBuilderException('fromObject() is required.');
        }

        if (this.fields.isEmpty()) {
            this.fields.add('Id');
        }

        // FLS check: remove fields the user can't access
        List<String> accessibleFields = new List<String>();
        if (flsEnforced) {
            Schema.DescribeSObjectResult objDescribe =
                Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

            for (String f : this.fields) {
                String fieldLower = f.toLowerCase();
                // Allow relationship fields and Id
                if (fieldLower == 'id' || f.contains('.')) {
                    accessibleFields.add(f);
                } else if (fieldMap.containsKey(fieldLower)
                           && fieldMap.get(fieldLower).getDescribe().isAccessible()) {
                    accessibleFields.add(f);
                }
                // Silently skip inaccessible fields
            }
        } else {
            accessibleFields = this.fields;
        }

        if (accessibleFields.isEmpty()) {
            accessibleFields.add('Id');
        }

        String query = 'SELECT ' + String.join(accessibleFields, ', ')
            + ' FROM ' + String.escapeSingleQuotes(this.objectName);

        if (!this.conditions.isEmpty()) {
            query += ' WHERE ' + String.join(this.conditions, ' AND ');
        }

        if (this.orderField != null) {
            query += ' ORDER BY ' + this.orderField + ' ' + this.orderDirection;
        }

        if (this.recordLimit != null) {
            query += ' LIMIT ' + this.recordLimit;
        }

        if (this.recordOffset != null) {
            query += ' OFFSET ' + this.recordOffset;
        }

        return query;
    }

    public List<SObject> execute() {
        return Database.query(build());
    }

    private String formatValue(Object value) {
        if (value == null) {
            return 'null';
        } else if (value instanceof String) {
            return '\'' + String.escapeSingleQuotes((String) value) + '\'';
        } else if (value instanceof Date) {
            return String.valueOf((Date) value);
        } else if (value instanceof DateTime) {
            return ((DateTime) value).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        } else if (value instanceof Boolean) {
            return String.valueOf(value);
        } else if (value instanceof Id) {
            return '\'' + String.valueOf(value) + '\'';
        } else {
            return String.valueOf(value);
        }
    }

    public class SOQLBuilderException extends Exception {}
}
