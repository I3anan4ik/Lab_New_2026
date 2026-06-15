USE AccessControlSystem;
GO

-- Проверка 1: Существует ли база?
SELECT 'База данных AccessControlSystem' as Info, DB_NAME() as CurrentDB;
GO

-- Проверка 2: Сколько сотрудников?
SELECT COUNT(*) as EmployeesCount FROM Employees;
GO

-- Проверка 3: Сколько событий?
SELECT COUNT(*) as EventsCount FROM Events;
GO

-- Проверка 4: Сколько нарушений?
SELECT COUNT(*) as ViolationsCount FROM Violations;
GO

-- Проверка 5: Показать 5 сотрудников
SELECT TOP 5 employee_id, full_name FROM Employees;
GO

-- Проверка 6: Показать 5 последних событий
SELECT TOP 5 event_id, employee_id, event_time FROM Events ORDER BY event_id DESC;
GO

-- Проверка 7: Типы нарушений
SELECT violation_type, COUNT(*) FROM Violations GROUP BY violation_type;
GO

SELECT @@SERVERNAME as ServerName;
GO