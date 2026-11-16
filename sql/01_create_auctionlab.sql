/*==============================================================
  01_create_auctionlab.sql

  Purpose : Creates the AuctionLab database, its schemas, and
            the first two tables of the ingest pipeline.
  Target  : SQL Server 2022 or later (any edition)
  Run as  : A login with permission to create databases
  Rerun   : Safe. Every step checks before it creates, so
            running the script again changes nothing and
            loses no data.

  Contains no server names, logins, passwords, or file paths.
  Connect to your own instance before running.
==============================================================*/

/*--------------------------------------------------------------
  STEP 1: Database
--------------------------------------------------------------*/
USE master;
GO
IF DB_ID(N'AuctionLab') IS NULL
BEGIN
    CREATE DATABASE AuctionLab;
    PRINT 'Step 1: database AuctionLab created.';
END
ELSE
    PRINT 'Step 1: database AuctionLab already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 2: Schemas
    stg      = raw files land here untouched
    analysis = private views and procedures
    pub      = the only schema the website may read
  (dbo is built in and holds the cleaned data)
--------------------------------------------------------------*/
USE AuctionLab;
GO
IF SCHEMA_ID(N'stg') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA stg AUTHORIZATION dbo;');
    PRINT 'Step 2: schema stg created.';
END
ELSE PRINT 'Step 2: schema stg already exists, skipped.';

IF SCHEMA_ID(N'analysis') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA analysis AUTHORIZATION dbo;');
    PRINT 'Step 2: schema analysis created.';
END
ELSE PRINT 'Step 2: schema analysis already exists, skipped.';

IF SCHEMA_ID(N'pub') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA pub AUTHORIZATION dbo;');
    PRINT 'Step 2: schema pub created.';
END
ELSE PRINT 'Step 2: schema pub already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 3: dbo.AuctionBatch
  One row per downloaded source file. The unique key on
  (SourceUrl, FileHash) means the same file can never be
  loaded twice.
--------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.AuctionBatch', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuctionBatch
    (
        BatchId       INT IDENTITY(1,1) NOT NULL,
        SourceUrl     NVARCHAR(500)     NOT NULL,
        FileHash      CHAR(64)          NOT NULL,   -- SHA-256 as hex text
        SaleDate      DATE              NULL,       -- read from the file footer
        DownloadedAt  DATETIME2(0)      NOT NULL
            CONSTRAINT DF_AuctionBatch_DownloadedAt DEFAULT (SYSUTCDATETIME()),
        RawLineCount  INT               NULL,
        BatchStatus   VARCHAR(20)       NOT NULL
            CONSTRAINT DF_AuctionBatch_Status DEFAULT ('Downloaded'),
        CONSTRAINT PK_AuctionBatch PRIMARY KEY CLUSTERED (BatchId),
        CONSTRAINT UQ_AuctionBatch_UrlHash UNIQUE (SourceUrl, FileHash)
    );
    PRINT 'Step 3: dbo.AuctionBatch created.';
END
ELSE PRINT 'Step 3: dbo.AuctionBatch already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 4: stg.AuctionListRaw
  Every text line from the source file, exactly as read, tied
  to its batch. Nothing is cleaned or dropped here, including
  footer lines.
--------------------------------------------------------------*/
IF OBJECT_ID(N'stg.AuctionListRaw', N'U') IS NULL
BEGIN
    CREATE TABLE stg.AuctionListRaw
    (
        RawId       BIGINT IDENTITY(1,1) NOT NULL,
        BatchId     INT                  NOT NULL,
        LineNumber  INT                  NOT NULL,
        RawText     NVARCHAR(500)        NOT NULL,
        LoadedAt    DATETIME2(0)         NOT NULL
            CONSTRAINT DF_AuctionListRaw_LoadedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_AuctionListRaw PRIMARY KEY CLUSTERED (RawId),
        CONSTRAINT FK_AuctionListRaw_Batch
            FOREIGN KEY (BatchId) REFERENCES dbo.AuctionBatch (BatchId),
        CONSTRAINT UQ_AuctionListRaw_BatchLine UNIQUE (BatchId, LineNumber)
    );
    PRINT 'Step 4: stg.AuctionListRaw created.';
END
ELSE PRINT 'Step 4: stg.AuctionListRaw already exists, skipped.';
GO

/*--------------------------------------------------------------
  CHECK: confirm everything is in place
--------------------------------------------------------------*/
SELECT s.name AS SchemaName, t.name AS TableName
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name IN (N'dbo', N'stg')
ORDER BY s.name, t.name;
GO

/*--------------------------------------------------------------
  OPTIONAL RESET (leave commented out)
  Uncomment and run ONLY to wipe these tables and start over.
  This deletes all rows in them.
--------------------------------------------------------------*/
-- USE AuctionLab;
-- GO
-- DROP TABLE IF EXISTS stg.AuctionListRaw;   -- child first
-- DROP TABLE IF EXISTS dbo.AuctionBatch;
-- GO
