USE AccessControlSystem;
GO

-- =====================================================
-- РЕГИСТРАЦИЯ СОБЫТИЯ ВХОДА/ВЫХОДА
-- =====================================================
CREATE OR ALTER PROCEDURE sp_RegisterEvent
    @CardUID NVARCHAR(32),
    @PointID INT,
    @EventTime DATETIME,
    @EventType SMALLINT,
    @EventID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @EmployeeID INT;
    DECLARE @AccessGranted BIT = 1;
    
    -- Проверяем сотрудника
    SELECT @EmployeeID = employee_id 
    FROM Employees 
    WHERE card_uid = @CardUID AND is_active = 1;
    
    IF @EmployeeID IS NULL
    BEGIN
        SET @AccessGranted = 0;
        SET @EmployeeID = -1;
    END
    
    -- Вставляем событие
    INSERT INTO Events (employee_id, point_id, event_time, event_type, access_granted)
    VALUES (@EmployeeID, @PointID, @EventTime, @EventType, @AccessGranted);
    
    SET @EventID = SCOPE_IDENTITY();
    
    -- Проверяем нарушение
    IF @AccessGranted = 1 AND @EventType = 1
    BEGIN
        DECLARE @WorkStart TIME;
        SELECT @WorkStart = work_start FROM Employees WHERE employee_id = @EmployeeID;
        
        IF CAST(@EventTime AS TIME) > @WorkStart
        BEGIN
            INSERT INTO Violations (event_id, employee_id, violation_type, violation_date, violation_time, severity, description)
            VALUES (@EventID, @EmployeeID, 'Опоздание', CAST(@EventTime AS DATE), CAST(@EventTime AS TIME), 1, 'Автоматическое обнаружение');
        END
    END
    
    SELECT @EventID as EventID, @AccessGranted as AccessGranted;
END;
GO

-- =====================================================
-- ПОЛУЧЕНИЕ СТАТИСТИКИ СОТРУДНИКА
-- =====================================================
CREATE OR ALTER PROCEDURE sp_GetEmployeeStats
    @EmployeeID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT 
        e.full_name,
        d.department_name,
        COUNT(DISTINCT CAST(ev.event_time AS DATE)) as working_days,
        COUNT(CASE WHEN ev.event_type = 1 THEN 1 END) as entries,
        COUNT(CASE WHEN ev.event_type = 2 THEN 1 END) as exits,
        COUNT(v.violation_id) as violations,
        AVG(CASE WHEN v.severity IS NOT NULL THEN v.severity ELSE 0 END) as avg_severity
    FROM Employees e
    LEFT JOIN Departments d ON e.department_id = d.department_id
    LEFT JOIN Events ev ON e.employee_id = ev.employee_id 
        AND ev.event_time BETWEEN @StartDate AND @EndDate
    LEFT JOIN Violations v ON e.employee_id = v.employee_id 
        AND v.violation_date BETWEEN @StartDate AND @EndDate
    WHERE e.employee_id = @EmployeeID
    GROUP BY e.full_name, d.department_name;
END;
GO

-- =====================================================
-- ПОЛУЧЕНИЕ ДАШБОРДА НАРУШЕНИЙ
-- =====================================================
CREATE OR ALTER PROCEDURE sp_GetViolationsDashboard
    @PeriodType NVARCHAR(10) = 'Month'
AS
BEGIN
    DECLARE @StartDate DATE;
    
    SET @StartDate = CASE @PeriodType
        WHEN 'Month' THEN DATEADD(MONTH, -1, GETDATE())
        WHEN 'Quarter' THEN DATEADD(MONTH, -3, GETDATE())
        WHEN 'Year' THEN DATEADD(YEAR, -1, GETDATE())
        ELSE DATEADD(MONTH, -1, GETDATE())
    END;
    
    -- Общая статистика
    SELECT 
        'total_violations' as metric,
        COUNT(*) as value
    FROM Violations
    WHERE violation_date >= @StartDate
    
    UNION ALL
    
    SELECT 
        'unique_violators',
        COUNT(DISTINCT employee_id)
    FROM Violations
    WHERE violation_date >= @StartDate
    
    UNION ALL
    
    SELECT 
        'late_arrivals',
        COUNT(*)
    FROM Violations
    WHERE violation_type = 'Опоздание' AND violation_date >= @StartDate
    
    UNION ALL
    
    SELECT 
        'early_departures',
        COUNT(*)
    FROM Violations
    WHERE violation_type = 'Ранний уход' AND violation_date >= @StartDate
    
    UNION ALL
    
    SELECT 
        'avg_violations_per_violator',
        CAST(CAST(COUNT(*) AS FLOAT) / COUNT(DISTINCT employee_id) AS NVARCHAR(20))
    FROM Violations
    WHERE violation_date >= @StartDate;
END;
GO

PRINT 'Все хранимые процедуры созданы!';
GO