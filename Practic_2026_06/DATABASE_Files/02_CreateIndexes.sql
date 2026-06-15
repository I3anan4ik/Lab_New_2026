USE AccessControlSystem;
GO

-- =====================================================
-- СОЗДАНИЕ ИНДЕКСОВ ДЛЯ УСКОРЕНИЯ ЗАПРОСОВ
-- =====================================================

-- Индексы для таблицы Events
CREATE INDEX IX_Events_EmployeeTime ON Events(employee_id, event_time);
CREATE INDEX IX_Events_Time ON Events(event_time);
CREATE INDEX IX_Events_Type ON Events(event_type);

-- Индексы для таблицы Violations
CREATE INDEX IX_Violations_EmployeeDate ON Violations(employee_id, violation_date);
CREATE INDEX IX_Violations_Date ON Violations(violation_date);
CREATE INDEX IX_Violations_Type ON Violations(violation_type);

-- Индексы для таблицы Employees
CREATE INDEX IX_Employees_CardUID ON Employees(card_uid);
CREATE INDEX IX_Employees_Department ON Employees(department_id);
CREATE INDEX IX_Employees_Active ON Employees(is_active);

-- Индексы для таблицы WorkingHoursLog
CREATE INDEX IX_WorkingHours_EmployeeDate ON WorkingHoursLog(employee_id, work_date);

PRINT 'Все индексы успешно созданы!';
GO