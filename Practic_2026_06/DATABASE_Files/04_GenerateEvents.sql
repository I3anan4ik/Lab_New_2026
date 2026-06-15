USE AccessControlSystem;
GO

-- =====================================================
-- ГЕНЕРАЦИЯ 200,000+ СОБЫТИЙ (БЕЗ ОШИБОК)
-- =====================================================

-- 1. Удаляем старые события (сначала удаляем связанные нарушения)
DELETE FROM Violations;
DELETE FROM Events;
GO

PRINT 'Начинаем генерацию событий...';
PRINT CONVERT(NVARCHAR, GETDATE(), 120);
GO

-- 2. Объявляем переменные внутри скрипта
DECLARE @StartDate DATE = DATEADD(DAY, -90, GETDATE());
DECLARE @EndDate DATE = GETDATE();
DECLARE @SecondsDiff INT = DATEDIFF(SECOND, @StartDate, @EndDate);
GO

-- 3. Вставляем данные (упрощенный и надежный способ)
WITH Numbers AS (
    SELECT TOP 200000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 as n
    FROM sys.objects a 
    CROSS JOIN sys.objects b 
),
EmployeeList AS (
    SELECT employee_id 
    FROM Employees 
    WHERE is_active = 1 AND employee_id <= 1000
)
INSERT INTO Events (employee_id, point_id, event_time, event_type, access_granted)
SELECT 
    e.employee_id,
    1 as point_id,  -- Временное значение
    DATEADD(SECOND, 
        ABS(CHECKSUM(NEWID())) % 7776000,  -- 90 дней в секундах
        DATEADD(DAY, -90, GETDATE())) as event_time,
    (ABS(CHECKSUM(NEWID())) % 2) + 1 as event_type,
    1 as access_granted
FROM EmployeeList e
CROSS JOIN Numbers n
WHERE n.n < 200  -- 200 событий на сотрудника
ORDER BY e.employee_id, n.n;
GO

PRINT 'Генерация событий завершена!';
GO

-- 4. Проверка
SELECT 
    COUNT(*) as TotalEvents,
    COUNT(DISTINCT employee_id) as UniqueEmployees,
    MIN(event_time) as FirstEvent,
    MAX(event_time) as LastEvent,
    COUNT(CASE WHEN event_type = 1 THEN 1 END) as EntryEvents,
    COUNT(CASE WHEN event_type = 2 THEN 1 END) as ExitEvents
FROM Events;
GO