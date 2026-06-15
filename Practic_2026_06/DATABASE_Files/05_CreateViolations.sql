USE AccessControlSystem;
GO

-- =====================================================
-- АВТОМАТИЧЕСКОЕ ВЫЯВЛЕНИЕ НАРУШЕНИЙ
-- =====================================================

-- Очищаем старые нарушения
TRUNCATE TABLE Violations;
GO

-- Вставляем нарушения (опоздания)
INSERT INTO Violations (event_id, employee_id, violation_type, violation_date, violation_time, severity, description)
SELECT 
    e.event_id,
    e.employee_id,
    'Опоздание' as violation_type,
    CAST(e.event_time AS DATE) as violation_date,
    CAST(e.event_time AS TIME) as violation_time,
    CASE 
        WHEN DATEPART(HOUR, e.event_time) = 9 AND DATEPART(MINUTE, e.event_time) > 0 THEN 1
        WHEN DATEPART(HOUR, e.event_time) = 10 THEN 2
        ELSE 3
    END as severity,
    CONCAT('Вход в ', FORMAT(e.event_time, 'HH:mm'), ' при норме ', emp.work_start) as description
FROM Events e
INNER JOIN Employees emp ON e.employee_id = emp.employee_id
WHERE e.event_type = 1  -- Вход
    AND CAST(e.event_time AS TIME) > emp.work_start  -- После начала работы
    AND DATEDIFF(MINUTE, emp.work_start, e.event_time) > 5;  -- Опоздание более 5 минут
GO

-- Вставляем нарушения (ранние уходы)
INSERT INTO Violations (event_id, employee_id, violation_type, violation_date, violation_time, severity, description)
SELECT 
    e.event_id,
    e.employee_id,
    'Ранний уход' as violation_type,
    CAST(e.event_time AS DATE) as violation_date,
    CAST(e.event_time AS TIME) as violation_time,
    CASE 
        WHEN DATEDIFF(MINUTE, e.event_time, emp.work_end) <= 30 THEN 1
        WHEN DATEDIFF(MINUTE, e.event_time, emp.work_end) <= 60 THEN 2
        ELSE 3
    END as severity,
    CONCAT('Выход в ', FORMAT(e.event_time, 'HH:mm'), ' при норме ', emp.work_end) as description
FROM Events e
INNER JOIN Employees emp ON e.employee_id = emp.employee_id
WHERE e.event_type = 2  -- Выход
    AND CAST(e.event_time AS TIME) < emp.work_end  -- До окончания работы
    AND DATEDIFF(MINUTE, e.event_time, emp.work_end) > 5;  -- Уход более чем на 5 минут раньше
GO

-- Статистика нарушений
SELECT 
    CASE violation_type
        WHEN 'Опоздание' THEN 'Опоздание'
        WHEN 'Ранний уход' THEN 'Ранний уход'
        ELSE violation_type
    END as violation_type,
    CASE severity
        WHEN 1 THEN 'Незначительное (до 15 мин)'
        WHEN 2 THEN 'Среднее (15-30 мин)'
        WHEN 3 THEN 'Серьезное (более 30 мин)'
    END as severity_level,
    COUNT(*) as Count,
    MIN(violation_date) as FirstViolation,
    MAX(violation_date) as LastViolation
FROM Violations
GROUP BY violation_type, severity
ORDER BY violation_type, severity;
GO

-- Топ-10 нарушителей за все время
SELECT TOP 10
    e.full_name,
    ISNULL(d.department_name, 'Не указан') as department,
    COUNT(*) as total_violations,
    SUM(CASE WHEN v.violation_type = 'Опоздание' THEN 1 ELSE 0 END) as late_arrivals,
    SUM(CASE WHEN v.violation_type = 'Ранний уход' THEN 1 ELSE 0 END) as early_departures,
    AVG(CAST(v.severity AS DECIMAL(3,1))) as avg_severity
FROM Violations v
INNER JOIN Employees e ON v.employee_id = e.employee_id
LEFT JOIN Departments d ON e.department_id = d.department_id
GROUP BY e.full_name, d.department_name
ORDER BY total_violations DESC;
GO

-- Дополнительный отчет: Нарушения по отделам
SELECT 
    ISNULL(d.department_name, 'Не указан') as department,
    COUNT(*) as total_violations,
    COUNT(DISTINCT v.employee_id) as violators_count,
    SUM(CASE WHEN v.violation_type = 'Опоздание' THEN 1 ELSE 0 END) as late_arrivals,
    SUM(CASE WHEN v.violation_type = 'Ранний уход' THEN 1 ELSE 0 END) as early_departures,
    AVG(CAST(v.severity AS DECIMAL(3,1))) as avg_severity
FROM Violations v
INNER JOIN Employees e ON v.employee_id = e.employee_id
LEFT JOIN Departments d ON e.department_id = d.department_id
GROUP BY d.department_name
ORDER BY total_violations DESC;
GO

-- Статистика по сотрудникам с нарушениями
SELECT 
    'Всего сотрудников с нарушениями' as Metric,
    COUNT(DISTINCT employee_id) as Value
FROM Violations
UNION ALL
SELECT 
    'Среднее нарушений на сотрудника',
    CAST(COUNT(*) / COUNT(DISTINCT employee_id) AS NVARCHAR(20))
FROM Violations
UNION ALL
SELECT 
    'Максимум нарушений у одного сотрудника',
    CAST(MAX(violation_count) AS NVARCHAR(20))
FROM (
    SELECT employee_id, COUNT(*) as violation_count
    FROM Violations
    GROUP BY employee_id
) t;
GO