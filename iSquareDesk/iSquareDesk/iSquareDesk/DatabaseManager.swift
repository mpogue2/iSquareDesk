import Foundation
import GRDB

class DatabaseManager {
    private var dbQueue: DatabaseQueue?
    
    init() {
    }
    
    func connectToDatabase(at path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        print("✅ Successfully connected to database at: \(path)")
    }
    
    func connectToInMemoryDatabase() throws {
        dbQueue = try DatabaseQueue()
        print("✅ Successfully connected to in-memory database")
    }
    
    func inspectDatabase() throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notConnected
        }
        
        try dbQueue.read { db in
            let tables = try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master 
                WHERE type='table' 
                ORDER BY name
            """)
            
            print("\n📊 Database Tables:")
            if tables.isEmpty {
                print("   No tables found")
            } else {
                for table in tables {
                    print("   - \(table)")
                    
                    let columns = try Row.fetchAll(db, sql: """
                        PRAGMA table_info('\(table)')
                    """)
                    
                    print("     Columns:")
                    for column in columns {
                        let name = column["name"] as String? ?? "unknown"
                        let type = column["type"] as String? ?? "unknown"
                        let notNull = column["notnull"] as Int? ?? 0
                        let pk = column["pk"] as Int? ?? 0
                        
                        var attributes = [String]()
                        if pk > 0 { attributes.append("PRIMARY KEY") }
                        if notNull > 0 { attributes.append("NOT NULL") }
                        
                        let attrString = attributes.isEmpty ? "" : " (\(attributes.joined(separator: ", ")))"
                        print("       • \(name): \(type)\(attrString)")
                    }
                }
            }
        }
    }
    
    func testSimpleQuery(tableName: String) throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notConnected
        }
        
        try dbQueue.read { db in
            let exists = try db.tableExists(tableName)
            print("\n🔍 Table '\(tableName)' exists: \(exists)")
            
            if exists {
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(tableName)") ?? 0
                print("   Row count: \(count)")
                
                if count > 0 {
                    print("\n   First 5 rows:")
                    let rows = try Row.fetchAll(db, sql: "SELECT * FROM \(tableName) LIMIT 5")
                    for (index, row) in rows.enumerated() {
                        print("   Row \(index + 1):")
                        for (column, value) in row {
                            print("     - \(column): \(value)")
                        }
                    }
                }
            }
        }
    }
    
    func createSampleTable() throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notConnected
        }
        
        try dbQueue.write { db in
            try db.create(table: "sample_data", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("value", .integer)
                t.column("created_at", .datetime).defaults(to: Date())
            }
            
            print("\n✅ Created sample_data table")
        }
    }
    
    func insertSampleData(name: String, value: Int) throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notConnected
        }
        
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO sample_data (name, value) VALUES (?, ?)",
                arguments: [name, value]
            )
            
            print("✅ Inserted: name='\(name)', value=\(value)")
        }
    }
    
    enum DatabaseError: Error {
        case notConnected
        
        var localizedDescription: String {
            switch self {
            case .notConnected:
                return "Database is not connected. Call connectToDatabase() first."
            }
        }
    }
}

extension DatabaseManager {
    func runAllTests() {
        print("\n🚀 Starting GRDB Database Tests\n")
        print("=" * 50)
        
        do {
            print("\n1️⃣ Testing in-memory database...")
            try connectToInMemoryDatabase()
            
            print("\n2️⃣ Creating sample table...")
            try createSampleTable()
            
            print("\n3️⃣ Inserting sample data...")
            try insertSampleData(name: "Test Item 1", value: 100)
            try insertSampleData(name: "Test Item 2", value: 200)
            try insertSampleData(name: "Test Item 3", value: 300)
            
            print("\n4️⃣ Inspecting database structure...")
            try inspectDatabase()
            
            print("\n5️⃣ Testing queries...")
            try testSimpleQuery(tableName: "sample_data")
            
            print("\n" + "=" * 50)
            print("✅ All tests completed successfully!")
            
        } catch {
            print("\n❌ Error: \(error)")
        }
    }
    
    func testWithExistingDatabase(at path: String) {
        print("\n🚀 Testing with existing database\n")
        print("=" * 50)
        
        do {
            print("\n1️⃣ Connecting to database at: \(path)")
            try connectToDatabase(at: path)
            
            print("\n2️⃣ Inspecting database structure...")
            try inspectDatabase()
            
            print("\n" + "=" * 50)
            print("✅ Database inspection completed!")
            
        } catch {
            print("\n❌ Error: \(error)")
        }
    }
}

fileprivate func *(string: String, count: Int) -> String {
    return String(repeating: string, count: count)
}