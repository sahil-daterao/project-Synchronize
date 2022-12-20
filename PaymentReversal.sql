USE CoSACS
GO
-- =============================================================================================
	-- Country: Jamica
	-- Version: 1.0
	-- Project Name: Bluestart
	-- File Name: PaymentReversal.sql
	-- File Type: MSSQL Server SQL Script File
	-- Title: Payment Transaction Reversal 
	-- Desc : This Script will insert record in fintrans to reverse the records it will be generic for all account, transtypecode
	-- Author: Ranjana Dongre, IGT
	-- Date: 19-09-2022
----========================================================================================================
	
DECLARE @p4 INT
DECLARE @Unique_Query_No varchar(100)

DECLARE @BranchNo smallint
declare @NoOfRowsReverse smallint
declare @acctno varchar(20) = '87300190230' --give the account number to be reverse
declare @TransTypeCode varchar(20) = 'PAY'
declare @NewTransTypeCode varchar(20) = 'COR'
declare @DateReversed date = GETDATE()
declare @DateTransFrom datetime = '2022-09-12 00:00:00.000' 
declare @DateTransTo datetime = '2022-09-12 23:59:59.999'
declare @NewFtNote varchar(20) = 'PREV'
declare @TransValue money = 0 --if 0 it will reverse all value if any other then it will reverse only that value
declare @RowsReverse varchar(20) = 'all' -- 'all' will reverse all, 'allbut1' will retain 1 and reverse others 
declare @NewTransRefNo int

BEGIN TRANSACTION;
	SET @Unique_Query_No = CONCAT('PaymentReversal_',@acctno,cast(GETDATE() as date), '.sql')
	IF EXISTS( SELECT scriptname FROM datafix WHERE scriptname LIKE @Unique_Query_No and VERSION=1)
	BEGIN
	    PRINT 'This script has already been run and can not be run twice. Please contact CoSACS Support Centre'
	END 
	ELSE
	BEGIN	
		SELECT 
			@NoOfRowsReverse = CASE WHEN @RowsReverse = 'All' THEN COUNT(1) WHEN @RowsReverse = 'allbut1' THEN COUNT(1)-1 END, @BranchNo = branchno 
		FROM fintrans 
		WHERE acctno = @acctno 
			AND transtypecode = @TransTypeCode 
			--AND CAST(datetrans AS DATE) = @DateTransFrom
			AND datetrans BETWEEN @DateTransFrom AND @DateTransTo
			AND transvalue = CASE WHEN @TransValue = 0 THEN TransValue ELSE @TransValue END
		GROUP BY branchno

		print concat('@NoOfRowsReverse : ', @NoOfRowsReverse)
		DECLARE @count INT;
		SET @count = 1;

		WHILE @count <= @NoOfRowsReverse
		BEGIN
		   PRINT @count
		   	----Get New TransRefNo and New BuffNo to insert in fintrans------	
			EXEC DN_BranchGetTransRefNoSP @branch=@branchno, @required= 1,@transno=@NewTransRefNo OUTPUT,@return=@p4 OUTPUT

			INSERT INTO [dbo].[fintrans]
				(origbr, BranchNo, AcctNo, TransRefNo, DateTrans, TransTypeCode, EmpeeNo, transupdated, transprinted, TransValue, bankcode, bankacctno, chequeno, Ftnotes, paymethod, runno, source, agrmtno, ExportedToTallyman)
			SELECT TOP 1 origbr, BranchNo, AcctNo, @NewTransRefNo, @DateReversed, @NewTransTypeCode, EmpeeNo, '' ,'N' ,-(TransValue), '' ,'' ,'', @NewFtNote, paymethod, '', source, agrmtno, ExportedToTallyman
			FROM fintrans 
			WHERE acctno = @acctno 
				AND transtypecode = @TransTypeCode 
				--AND CAST(datetrans AS DATE) = @DateTransFrom
				AND datetrans BETWEEN @DateTransFrom AND @DateTransTo
			AND transvalue = CASE WHEN @TransValue = 0 THEN TransValue ELSE @TransValue END

		   SET @count = @count + 1;
		END;

		----Insert record into datafix table to record change
		INSERT INTO Datafix 
		    (ScriptRunDate, ScriptName, DESCRIPTION, Author, VERSION)
		SELECT GETDATE(), @Unique_Query_No, 
		    CONCAT('Payment Reversal for Acctno :  ',@acctno),
		    'Ranjana Dongre, IGT', 1
	END
COMMIT TRANSACTION;
--ROLLBACK TRANSACTION;