# SQL Parser Feature Roadmap

This document outlines missing features compared to comprehensive SQL parsers like DataFusion sqlparser-rs. Current implementation provides ~30% feature coverage with strong support for analytical workloads and comprehensive CRUD operations.

## High Priority (Core Functionality)

### DDL Enhancements
- [x] **CREATE INDEX** - Index creation with various types (BTREE, HASH, UNIQUE) ✅ **COMPLETED**
- [x] **DROP INDEX** - Index removal operations ✅ **COMPLETED**
- [x] **CREATE DATABASE/SCHEMA** - Database and schema management ✅ **COMPLETED**
- [x] **CREATE FUNCTION/PROCEDURE** - User-defined functions and procedures ✅ **COMPLETED**
- [ ] **CREATE SEQUENCE** - Sequence generators
- [ ] **ALTER INDEX** - Index modifications

### DML Extensions  
- [x] **MERGE statements** - UPSERT operations for data synchronization ✅ **COMPLETED**
- [ ] **Advanced INSERT** - More conflict resolution options beyond basic OR clauses
- [ ] **COPY statements** - Bulk data import/export operations
- [ ] **LOAD DATA** - MySQL-style data loading

### Essential Utilities
- [ ] **USE database** - Database switching (critical for multi-database environments)
- [ ] **EXPLAIN variants** - EXPLAIN ANALYZE, EXPLAIN VERBOSE, etc.
- [ ] **PREPARE/EXECUTE** - Prepared statement support
- [ ] **SHOW variants** - SHOW FUNCTIONS, SHOW VARIABLES, SHOW STATUS

## Medium Priority (Enhanced Functionality)

### Advanced Query Features  
- [ ] **PIVOT/UNPIVOT** - Data reshaping operations
- [ ] **LATERAL joins** - Advanced join patterns
- [ ] **TABLESAMPLE** - Statistical sampling operations
- [ ] **Table-valued functions** - Functions returning table results

### Expression Extensions
- [ ] **JSON operations** - JSON path expressions, JSON_EXTRACT, etc.
- [ ] **Map/Dictionary operations** - Key-value pair handling
- [ ] **Advanced string functions** - REGEXP, SIMILAR TO, advanced TRIM
- [ ] **Type operations** - CONVERT, AT TIME ZONE, COLLATE
- [ ] **Set operations** - ANY/ALL/SOME operators

### Additional Statement Types
- [ ] **ATTACH/DETACH DATABASE** - Database attachment (SQLite-style)
- [ ] **PRAGMA statements** - SQLite configuration directives
- [ ] **FLUSH operations** - Cache and buffer management
- [ ] **OPTIMIZE TABLE** - Table optimization commands

### Dialect Extensions
- [ ] **Microsoft SQL Server (T-SQL)** - MSSQL-specific syntax and features
- [ ] **Apache Hive (HQL)** - Hadoop Query Language support  
- [ ] **Databricks SQL** - Spark SQL extensions
- [ ] **ANSI SQL compliance mode** - Strict standard adherence

## Lower Priority (Specialized Features)

### Advanced Analytics
- [ ] **OLAP functions** - Advanced ROLLUP, CUBE, GROUPING SETS
- [ ] **Time series functions** - Temporal analytics and window functions
- [ ] **Statistical functions** - PERCENTILE, STDDEV, advanced aggregates
- [ ] **Machine learning functions** - Predictive analytics syntax

### Administrative Features  
- [ ] **User management** - CREATE/ALTER/DROP USER, ROLE management
- [ ] **Security features** - Row-level security, column masking
- [ ] **System catalogs** - Information schema queries
- [ ] **Backup/restore** - Database maintenance operations

### Programming Constructs
- [ ] **Control flow** - IF/WHILE/CASE statements (not expressions)
- [ ] **Error handling** - RAISE, ASSERT, TRY/CATCH blocks
- [ ] **Variable declarations** - Local and session variables
- [ ] **Cursors** - OPEN, CLOSE, FETCH operations

### Data Engineering
- [ ] **Streaming operations** - Real-time data processing syntax
- [ ] **Partitioning** - Advanced table partitioning schemes  
- [ ] **File format support** - Parquet, ORC, Avro syntax
- [ ] **External tables** - External data source integration

## Implementation Notes

### Architecture Principles
- Maintain modular design with separate files for each feature area
- Follow existing patterns for AST definition, parsing, and pretty printing
- Ensure comprehensive test coverage for all new features
- Support multiple dialects where features overlap

### Development Guidelines
- Implement high-priority features first to maximize utility
- Consider backward compatibility with existing API
- Document dialect-specific behaviors clearly
- Include error handling and helpful error messages

### Testing Strategy
- Add both positive and negative test cases
- Test dialect-specific variations
- Verify pretty printing round-trip accuracy
- Include complex real-world query examples

## Progress Tracking

### Completed Major Features
1. **Window Functions** - Complete OVER clause support with partitioning, ordering, and frame specifications
2. **CREATE INDEX** - Comprehensive index creation with all standard options
3. **DROP INDEX** - Index removal with concurrency and existence checks
4. **CREATE DATABASE/SCHEMA** - Database and schema management with character sets
5. **CREATE FUNCTION/PROCEDURE** - User-defined functions and procedures with parameters
6. **MERGE Statements** - Advanced UPSERT operations for data synchronization

### Current Coverage
- **~30% feature coverage** compared to comprehensive SQL parsers
- **284+ comprehensive tests** with high-quality test coverage
- **5 major SQL language categories** fully supported (DML, DDL, TCL, DCL, Utility)
- **6+ SQL dialects** with dialect-specific extensions

### Next Up
- **CREATE SEQUENCE** - Sequence generators for auto-incrementing values
- **ALTER INDEX** - Index modification operations
- **Advanced INSERT** - Enhanced conflict resolution beyond basic OR clauses