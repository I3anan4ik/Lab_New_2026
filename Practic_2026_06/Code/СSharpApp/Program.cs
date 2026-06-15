using Microsoft.Data.SqlClient;
using System.Diagnostics;

namespace AccessControlCSharp;

class Program
{
    // ВАЖНО: ИЗМЕНИТЕ ИМЯ СЕРВЕРА НА ВАШЕ ИЗ SSMS
    static string connectionString = "Server=DESKTOP-TK7GI2K\\I3ANAN4IK;Database=AccessControlSystem;Trusted_Connection=True;TrustServerCertificate=True;";

    static async Task Main(string[] args)
    {
        Console.WriteLine("================================================================================");
        Console.WriteLine("     КОНТРОЛЬНО-ПРОПУСКНАЯ СИСТЕМА (C#)");
        Console.WriteLine("     Учет рабочего времени на основе RFID-карт");
        Console.WriteLine("================================================================================");
        Console.WriteLine();

        bool exit = false;
        while (!exit)
        {
            Console.WriteLine("\n================================================================================");
            Console.WriteLine("ГЛАВНОЕ МЕНЮ:");
            Console.WriteLine("================================================================================");
            Console.WriteLine("1. Регистрация события входа/выхода");
            Console.WriteLine("2. Вывод статистики прихода и ухода");
            Console.WriteLine("3. Вывод нарушителей (группировка по датам)");
            Console.WriteLine("4. Вывод нарушителей за месяц/квартал/год");
            Console.WriteLine("5. ТЕСТ ПРОИЗВОДИТЕЛЬНОСТИ (1000 вставок)");
            Console.WriteLine("6. Полная аналитика нарушений");
            Console.WriteLine("0. Выход");
            Console.Write("\nВыберите пункт: ");

            string choice = Console.ReadLine() ?? "0";
            Console.WriteLine();

            switch (choice)
            {
                case "1": await RegisterEvent(); break;
                case "2": await ShowStatistics(); break;
                case "3": await ShowViolatorsByDate(); break;
                case "4": await ShowViolatorsByPeriod(); break;
                case "5": await PerformanceTest(); break;
                case "6": await FullAnalytics(); break;
                case "0": exit = true; break;
                default: Console.WriteLine("Неверный выбор!"); break;
            }
        }

        Console.WriteLine("\nПрограмма завершена. Нажмите любую клавишу...");
        Console.ReadKey();
    }

    // =====================================================
    // 1. РЕГИСТРАЦИЯ СОБЫТИЯ
    // =====================================================
    static async Task RegisterEvent()
    {
        Console.WriteLine("================================================================================");
        Console.WriteLine("РЕГИСТРАЦИЯ СОБЫТИЯ");
        Console.WriteLine("================================================================================");

        Console.Write("Введите ID сотрудника: ");
        if (!int.TryParse(Console.ReadLine(), out int empId))
        {
            Console.WriteLine("Неверный ID!");
            return;
        }

        Console.Write("Тип события (1-Вход, 2-Выход): ");
        if (!int.TryParse(Console.ReadLine(), out int eventType) || (eventType != 1 && eventType != 2))
        {
            Console.WriteLine("Неверный тип события!");
            return;
        }

        try
        {
            using var conn = new SqlConnection(connectionString);
            await conn.OpenAsync();

            string sql = @"INSERT INTO Events (employee_id, point_id, event_time, event_type, access_granted) 
                           VALUES (@empId, 1, GETDATE(), @type, 1)";

            using var cmd = new SqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("@empId", empId);
            cmd.Parameters.AddWithValue("@type", eventType);

            await cmd.ExecuteNonQueryAsync();

            Console.WriteLine($"\n[OK] Событие зарегистрировано!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ОШИБКА] {ex.Message}");
        }
    }

    // =====================================================
    // 2. СТАТИСТИКА ПРИХОДА И УХОДА
    // =====================================================
    static async Task ShowStatistics()
    {
        Console.WriteLine("================================================================================");
        Console.WriteLine("СТАТИСТИКА ПРИХОДА И УХОДА (последние 30 дней)");
        Console.WriteLine("================================================================================");

        var stopwatch = Stopwatch.StartNew();

        try
        {
            using var conn = new SqlConnection(connectionString);
            await conn.OpenAsync();

            string sql = @"
                SELECT 
                    FORMAT(ev.event_time, 'yyyy-MM-dd') as Date,
                    COUNT(CASE WHEN ev.event_type = 1 THEN 1 END) as Entries,
                    COUNT(CASE WHEN ev.event_type = 2 THEN 1 END) as Exits
                FROM Events ev
                WHERE ev.event_time > DATEADD(DAY, -30, GETDATE())
                GROUP BY FORMAT(ev.event_time, 'yyyy-MM-dd')
                ORDER BY Date DESC";

            using var cmd = new SqlCommand(sql, conn);
            using var reader = await cmd.ExecuteReaderAsync();

            Console.WriteLine("\n+------------+----------+----------+");
            Console.WriteLine("|    Дата    |  Входы   |  Выходы  |");
            Console.WriteLine("+------------+----------+----------+");

            int totalEntries = 0, totalExits = 0;
            while (await reader.ReadAsync())
            {
                string date = reader.GetString(0);
                int entries = reader.GetInt32(1);
                int exits = reader.GetInt32(2);
                totalEntries += entries;
                totalExits += exits;
                Console.WriteLine($"| {date,-10} | {entries,8} | {exits,8} |");
            }
            Console.WriteLine("+------------+----------+----------+");
            Console.WriteLine($"| ИТОГО:     | {totalEntries,8} | {totalExits,8} |");
            Console.WriteLine("+------------+----------+----------+");

            stopwatch.Stop();
            Console.WriteLine($"\n[Время] Выполнения: {stopwatch.ElapsedMilliseconds} мс");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ОШИБКА] {ex.Message}");
        }
    }

    // =====================================================
    // 3. НАРУШИТЕЛИ ПО ДАТАМ
    // =====================================================
    static async Task ShowViolatorsByDate()
    {
        Console.WriteLine("================================================================================");
        Console.WriteLine("НАРУШИТЕЛИ ПО ДАТАМ (последние 90 дней)");
        Console.WriteLine("================================================================================");

        var stopwatch = Stopwatch.StartNew();

        try
        {
            using var conn = new SqlConnection(connectionString);
            await conn.OpenAsync();

            string sql = @"
                SELECT TOP 20
                    e.full_name,
                    FORMAT(v.violation_date, 'yyyy-MM-dd') as ViolationDate,
                    COUNT(*) as Count,
                    v.violation_type
                FROM Violations v
                INNER JOIN Employees e ON v.employee_id = e.employee_id
                WHERE v.violation_date > DATEADD(DAY, -90, GETDATE())
                GROUP BY e.full_name, FORMAT(v.violation_date, 'yyyy-MM-dd'), v.violation_type
                ORDER BY Count DESC";

            using var cmd = new SqlCommand(sql, conn);
            using var reader = await cmd.ExecuteReaderAsync();

            Console.WriteLine("\n+--------------------------------+------------+----------+-----------------+");
            Console.WriteLine("|           Сотрудник            |    Дата    |  Кол-во  |      Тип        |");
            Console.WriteLine("+--------------------------------+------------+----------+-----------------+");

            while (await reader.ReadAsync())
            {
                string name = reader.GetString(0);
                string date = reader.GetString(1);
                int count = reader.GetInt32(2);
                string type = reader.GetString(3);

                if (name.Length > 30) name = name.Substring(0, 27) + "...";
                Console.WriteLine($"| {name,-30} | {date,-10} | {count,8} | {type,-15} |");
            }
            Console.WriteLine("+--------------------------------+------------+----------+-----------------+");

            stopwatch.Stop();
            Console.WriteLine($"\n[Время] Выполнения: {stopwatch.ElapsedMilliseconds} мс");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ОШИБКА] {ex.Message}");
        }
    }

    // =====================================================
    // 4. НАРУШИТЕЛИ ПО ПЕРИОДАМ
    // =====================================================
    static async Task ShowViolatorsByPeriod()
    {
        Console.WriteLine("================================================================================");
        Console.WriteLine("НАРУШИТЕЛИ ПО ПЕРИОДАМ");
        Console.WriteLine("================================================================================");

        var periods = new[] { ("Месяц", -30), ("Квартал", -90), ("Год", -365) };

        foreach (var (periodName, days) in periods)
        {
            Console.WriteLine($"\n--- {periodName.ToUpper()} ---");

            using var conn = new SqlConnection(connectionString);
            await conn.OpenAsync();

            string sql = $@"
                SELECT TOP 10
                    e.full_name,
                    COUNT(*) as Count,
                    v.violation_type
                FROM Violations v
                INNER JOIN Employees e ON v.employee_id = e.employee_id
                WHERE v.violation_date > DATEADD(DAY, {days}, GETDATE())
                GROUP BY e.full_name, v.violation_type
                ORDER BY Count DESC";

            using var cmd = new SqlCommand(sql, conn);
            using var reader = await cmd.ExecuteReaderAsync();

            Console.WriteLine("+--------------------------------+----------+-----------------+");
            Console.WriteLine("|           Сотрудник            |  Кол-во  |      Тип        |");
            Console.WriteLine("+--------------------------------+----------+-----------------+");

            while (await reader.ReadAsync())
            {
                string name = reader.GetString(0);
                int count = reader.GetInt32(1);
                string type = reader.GetString(2);

                if (name.Length > 30) name = name.Substring(0, 27) + "...";
                Console.WriteLine($"| {name,-30} | {count,8} | {type,-15} |");
            }
            Console.WriteLine("+--------------------------------+----------+-----------------+");
        }
    }

    // =====================================================
    // 5. ТЕСТ ПРОИЗВОДИТЕЛЬНОСТИ (1000 вставок)
    // =====================================================
    static async Task PerformanceTest()
    {
        Console.WriteLine("================================================================================");
        Console.WriteLine("ТЕСТ ПРОИЗВОДИТЕЛЬНОСТИ (1000 вставок)");
        Console.WriteLine("================================================================================");

        var memBefore = GC.GetTotalMemory(true);
        var stopwatch = Stopwatch.StartNew();

        try
        {
            using var conn = new SqlConnection(connectionString);
            await conn.OpenAsync();

            for (int i = 1; i <= 1000; i++)
            {
                int empId = (i % 1000) + 1;
                int eventType = (i % 2) + 1;

                string sql = @"INSERT INTO Events (employee_id, point_id, event_time, event_type, access_granted) 
                               VALUES (@empId, 1, GETDATE(), @type, 1)";

                using var cmd = new SqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@empId", empId);
                cmd.Parameters.AddWithValue("@type", eventType);
                await cmd.ExecuteNonQueryAsync();
            }

            stopwatch.Stop();
            var memAfter = GC.GetTotalMemory(false);

            Console.WriteLine($"\n[РЕЗУЛЬТАТЫ ТЕСТА]:");
            Console.WriteLine($"   Время выполнения: {stopwatch.ElapsedMilliseconds} мс");
            Console.WriteLine($"   Среднее время на вставку: {stopwatch.ElapsedMilliseconds / 1000.0:F2} мс");
            Console.WriteLine($"   Память до/после: {memBefore / 1024 / 1024} MB -> {memAfter / 1024 / 1024} MB");

            // Сохраняем результат в файл
            string resultLine = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss},Insert1000,{stopwatch.ElapsedMilliseconds},{memAfter - memBefore}";
            await File.AppendAllTextAsync("performance_results.csv", resultLine + Environment.NewLine);
            Console.WriteLine($"\n[СОХРАНЕНО] Результат сохранен в performance_results.csv");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ОШИБКА] {ex.Message}");
        }
    }

    // =====================================================
    // 6. ПОЛНАЯ АНАЛИТИКА
    // =====================================================
    static async Task FullAnalytics()
    {
        Console.WriteLine("================================================================================");
        Console.WriteLine("ПОЛНАЯ АНАЛИТИКА НАРУШЕНИЙ");
        Console.WriteLine("================================================================================");

        try
        {
            using var conn = new SqlConnection(connectionString);
            await conn.OpenAsync();

            string sql = @"
                SELECT 
                    (SELECT COUNT(DISTINCT employee_id) FROM Violations) as Violators,
                    (SELECT COUNT(*) FROM Violations) as TotalViolations,
                    (SELECT COUNT(*) FROM Events) as TotalEvents,
                    (SELECT COUNT(*) FROM Employees) as TotalEmployees";

            using var cmd = new SqlCommand(sql, conn);
            using var reader = await cmd.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                Console.WriteLine($"\n[СТАТИСТИКА]:");
                Console.WriteLine($"   Всего сотрудников: {reader.GetInt32(3)}");
                Console.WriteLine($"   Всего событий: {reader.GetInt32(2):N0}");
                Console.WriteLine($"   Всего нарушений: {reader.GetInt32(1):N0}");
                Console.WriteLine($"   Нарушителей: {reader.GetInt32(0)}");
                if (reader.GetInt32(2) > 0)
                {
                    double percent = reader.GetInt32(1) * 100.0 / reader.GetInt32(2);
                    Console.WriteLine($"   Процент нарушений от событий: {percent:F2}%");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ОШИБКА] {ex.Message}");
        }
    }
}