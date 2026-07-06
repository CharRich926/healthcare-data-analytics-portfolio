SELECT name, type_desc, is_unique
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.authorizations');