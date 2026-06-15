USE AccessControlSystem;
GO

-- =====================================================
-- ОТЧЕТ 1: Нарушители по датам (последние 90 дней)
-- =====================================================
CREATE OR ALTER PROCEDURE sp_GetViolatorsByDate
    @DaysBack INT = 90
AS
BEGIN
    SELECT TOP 50
        e.full_name,
        d.department_name,
        v.violation_date,
        COUNT(*) as violation_count,
        STRING_AGG(v.violation_type, ', ') as violation_types,
        MIN(v.severity) as max_severity
    FROM Violations v
    INNER JOIN Employees e ON v.employee_id = e.employee_id
    INNER JOIN Departments d ON e.department_id = d.department_id
    WHERE v.violation_date >= DATEADD(DAY, -@DaysBack, GETDATE())
    GROUP BY e.full_name, d.department_name, v.violation_date
    HAVING COUNT(*) >= 2
    ORDER BY violation_count DESC, max_severity DESC;
END;
GO

-- =====================================================
-- ОТЧЕТ 2: ТОП нарушителей по периодам
-- =====================================================
CREATE OR ALTER PROCEDURE sp_GetTopViolators
    @PeriodType NVARCHAR(10), -- 'Month', 'Quarter', 'Year'
    @TopCount INT = 10
AS
BEGIN
    DECLARE @StartDate DATE;
    
    SET @StartDate = CASE @PeriodType
        WHEN 'Month' THEN DATEADD(MONTH, -1, GETDATE())
        WHEN 'Quarter' THEN DATEADD(MONTH, -3, GETDATE())
        WHEN 'Year' THEN DATEADD(YEAR, -1, GETDATE())
        ELSE DATEADD(MONTH, -1, GETDATE())
    END;
    
    SELECT TOP (@TopCount)
        e.full_name,
        d.department_name,
        COUNT(*) as total_violations,
        SUM(CASE WHEN v.violation_type = 'Опоздание' THEN 1 ELSE 0 END) as late_arrivals,
        SUM(CASE WHEN v.violation_type = 'Ранний уход' THEN 1 ELSE 0 END) as early_departures,
        AVG(v.severity) as avg_severity
    FROM Violations v
    INNER JOIN Employees e ON v.employee_id = e.employee_id
    INNER JOIN Departments d ON e.department_id = d.department_id
    WHERE v.violation_date >= @StartDate
    GROUP BY e.full_name, d.department_name
    HAVING COUNT(*) > 3
    ORDER BY total_violations DESC;
END;
GO

-- =====================================================
-- ОТЧЕТ 3: Статистика посещаемости
-- =====================================================
CREATE OR ALTER PROCEDURE sp_GetAttendanceStats
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT 
        e.full_name,
        d.department_name,
        COUNT(DISTINCT CAST(eve.event_time AS DATE)) as days_worked,
        COUNT(CASE WHEN eve.event_type = 1 THEN 1 END) as total_entries,
        COUNT(CASE WHEN eve.event_type = 2 THEN 1 END) as total_exits,
        COUNT(v.violation_id) as total_violations
    FROM Employees e
    INNER JOIN Departments d ON e.department_id = d.department_id
    LEFT JOIN Events eve ON e.employee_id = eve.employee_id 
        AND eve.event_time BETWEEN @StartDate AND @EndDate
    LEFT JOIN Violations v ON e.employee_id = v.employee_id 
        AND v.violation_date BETWEEN @StartDate AND @EndDate
    WHERE e.is_active = 1
    GROUP BY e.full_name, d.department_name
    ORDER BY total_violations DESC;
END;
GO

-- =====================================================
-- ВЫПОЛНЕНИЕ ОТЧЕТОВ
-- =====================================================

PRINT '=== ОТЧЕТ: Нарушители по датам ===';
EXEC sp_GetViolatorsByDate @DaysBack = 90;

PRINT '=== ОТЧЕТ: ТОП нарушителей за месяц ===';
EXEC sp_GetTopViolators @PeriodType = 'Month', @TopCount = 10;

PRINT '=== ОТЧЕТ: ТОП нарушителей за квартал ===';
EXEC sp_GetTopViolators @PeriodType = 'Quarter', @TopCount = 10;

PRINT '=== ОТЧЕТ: Статистика посещаемости ===';
EXEC sp_GetAttendanceStats @StartDate = '2025-01-01', @EndDate = '2025-03-31';
GO