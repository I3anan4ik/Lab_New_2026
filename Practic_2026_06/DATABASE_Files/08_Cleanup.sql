USE AccessControlSystem;
GO

-- =====================================================
-- АРХИВИРОВАНИЕ СТАРЫХ ДАННЫХ
-- =====================================================

-- Создание архивной таблицы
CREATE TABLE Events_Archive (
    event_id BIGINT PRIMARY KEY,
    employee_id INT,
    point_id INT,
    event_time DATETIME,
    event_type SMALLINT,
    access_granted BIT,
    archived_date DATETIME DEFAULT GETDATE()
);
GO

-- Архивация данных старше 1 года
INSERT INTO Events_Archive (event_id, employee_id, point_id, event_time, event_type, access_granted)
SELECT event_id, employee_id, point_id, event_time, event_type, access_granted
FROM Events
WHERE event_time < DATEADD(YEAR, -1, GETDATE());

-- Удаление архивированных данных
DELETE FROM Events
WHERE event_time < DATEADD(YEAR, -1, GETDATE());
GO

-- =====================================================
-- ОБНОВЛЕНИЕ СТАТИСТИК
-- =====================================================
UPDATE STATISTICS Events;
UPDATE STATISTICS Violations;
UPDATE STATISTICS Employees;
GO

-- =====================================================
-- ПЕРЕСТРОЙКА ИНДЕКСОВ
-- =====================================================
ALTER INDEX ALL ON Events REBUILD;
ALTER INDEX ALL ON Violations REBUILD;
ALTER INDEX ALL ON Employees REBUILD;
GO

-- =====================================================
-- ОЧИСТКА ЛОГА ТРАНЗАКЦИЙ
-- =====================================================
DBCC SHRINKFILE (AccessControlSystem_Log, 100);
GO

PRINT 'Обслуживание базы данных завершено!';
GO