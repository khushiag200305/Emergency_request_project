# Emergency_request_project

## Database Setup

This app reads its MySQL connection details from environment variables. You can use a local MySQL server on your Mac, or point the app at one shared hosted database that every clone uses.

Copy [.env.example](.env.example) to `.env` and set these values:

- `MYSQL_HOST`
- `MYSQL_PORT`
- `MYSQL_USER`
- `MYSQL_PASSWORD`
- `MYSQL_DATABASE`
- `SECRET_KEY`

## How To Start The Database On Mac

1. Install MySQL if it is not already installed:

	```bash
	brew install mysql
	```

2. Start the MySQL service:

	```bash
	brew services start mysql
	```

3. Check that MySQL is running:

	```bash
	mysqladmin -h 127.0.0.1 -P 3306 ping
	```

4. Create the database and load the seed data from the SQL file:

	```bash
	mysql -u root < Emergency_Response_DB_100Records.sql
	```

5. If you want to confirm the import, open MySQL and check the database:

	```bash
	mysql -u root
	SHOW DATABASES;
	USE Emergency_Service_DB;
	SHOW TABLES;
	```

## How To Start The Database On Windows

1. Install MySQL Server and MySQL Shell/Client from the official MySQL installer.

2. Start the MySQL service.

If `MySQL80` does not exist on your system, first list services and use the matching name:

	```powershell
	Get-Service -Name MySQL*
	```

PowerShell:

	```powershell
	Start-Service -Name MySQL80
	```

Command Prompt:

	```bat
	net start MySQL80
	```

3. Check that MySQL is running.

PowerShell or Command Prompt:

	```bat
	mysqladmin -h 127.0.0.1 -P 3306 ping
	```

4. Import the database dump.

PowerShell (from project folder):

	```powershell
	Get-Content .\Emergency_Response_DB_100Records.sql | mysql -u root
	```

Command Prompt (from project folder):

	```bat
	mysql -u root < Emergency_Response_DB_100Records.sql
	```

5. Verify the database import.

	```bat
	mysql -u root
	SHOW DATABASES;
	USE Emergency_Service_DB;
	SHOW TABLES;
	```

6. Install Python dependencies and run the app.

PowerShell or Command Prompt:

	```bat
	pip install -r requirements.txt
	python app.py
	```

## Start The App

1. Install Python dependencies:

	```bash
	pip install -r requirements.txt
	```

2. Make sure your `.env` file points to the database:

	```env
	MYSQL_HOST=127.0.0.1
	MYSQL_PORT=3306
	MYSQL_USER=root
	MYSQL_PASSWORD=
	MYSQL_DATABASE=Emergency_Service_DB
	```

3. Run the app:

	```bash
	python app.py
	```

## Shared Database Option

If you want every clone of this repo to use the same data, create one hosted MySQL database and import [Emergency_Response_DB_100Records.sql](Emergency_Response_DB_100Records.sql) into it once. Then update `.env` in each clone to point to that hosted host, user, password, and port.

If you are using a hosted MySQL provider, keep the database credentials in a secure secret store or deployment environment rather than committing them to Git.