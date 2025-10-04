These are the latest code files for DigiDocs as of now.

Notes:
- Download DB browser for SQLite database
- Several codes are AI kaya need talaga aralin :>>
- Run only on "windows" devices "flutter run -d windows" (di gagana yung database if edge or chrome lang yung connected)
- These files will change, please check nalang time to time :>>

Files:

digidocs.db 

            ----> SQLite Database
            ----> Runs on DB Browser (download niyo nalang muna)

pubspec.yaml 

              ----> Flutter dependencies, assets, and other settings
              ----> Makes external packages (sqflite_common_ffi(andito yung database, since gagawa sya ng new SQLite file if ever nonexistent and SQLite))

main.dart (entry point) 

            ----> Initializes the SQLite (sqflite_common_ffi) and launches the app. 
            ----> imports db_service.dart if ever yung SQLite database file is nonexistent

dashboard.dart (UI) 

            ----> main interface after login
            ----> displays CRUD operations
            ----> may search bar, logout,

db_helper.dart (low-level DB setup) 

            ----> andito yung table creation (database setup)
            ----> manages database version
            ----> used by db_service.dart to perform CRUD operations

db_service.dart (high-level DB operations) 

            ----> high-level database operation like adding, updating, deleting users or documents. 
            ----> acts as a bridge between dashboard.dart (UI) and db_helper.dart (database)
            
