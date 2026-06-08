# Pharmacy SelfHosted System

A modern, self-hosted Pharmacy Management System designed for single-user/independent pharmacy environments. The system consists of a high-performance **Python FastAPI Backend** running PostgreSQL and a cross-platform **Flutter Client Application** (supporting Windows, Android, iOS, and Web).

---

## Project Architecture

The project is structured into two main components:
1. **`/Backend`**: The FastAPI application serving REST endpoints, database schemas (via SQLAlchemy), authentication, and business logic.
2. **`/flutter_pharmacy`**: The Flutter frontend application providing a clean user experience for point-of-sale (POS), inventory management, and customer/prescription tracking.

---

##  Prerequisites

Ensure you have the following installed on your machine:
* [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Recommended for hosting the backend)
* [Python 3.10+](https://www.python.org/) (For local backend development)
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (For running the frontend client)
* [Git](https://git-scm.com/)

---

## 🚀 Backend Setup

### Option A: Running with Docker (Recommended / Production)

The backend runs inside a self-contained Docker container hosting both the **PostgreSQL database** and the **FastAPI application**. The database tables are automatically generated, and a clean admin account is seeded during the build process.

1. **Build the Docker image:**
   ```bash
   docker build -t pharmacy .
   ```

2. **Run the Docker container:**
   ```bash
   docker run -p 8000:8000 --name pharmacy --rm pharmacy
   ```
   * The REST API will be available at **`http://localhost:8000`**.
   * Database data is automatically initialized inside the container.

---

### Option B: Local Python Development Setup

If you want to run the backend without Docker (directly on your host system):

1. **Navigate to the Backend directory:**
   ```bash
   cd Backend
   ```

2. **Create and activate a virtual environment:**
   * **Windows:**
     ```bash
     python -m venv .venv
     .venv\Scripts\activate
     ```
   * **Mac/Linux:**
     ```bash
     python3 -m venv .venv
     source .venv/bin/activate
     ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configuration Settings:**
   The `config.yaml` files are used to manage configurations and are already tracked and present in both the `Backend/` and `flutter_pharmacy/` directories. These files contain **ready-to-use default configurations** that work out of the box, but they can be inspected and changed by the user if needed (e.g., inside `Backend/config.yaml`):
   ```yaml
   DATABASE_URL: "postgresql+asyncpg://pharmacy:PassWD@localhost:5432/pharmacy"
   JWT_SECRET: "your_super_secret_jwt_key_here"
   JWT_ALGORITHM: "HS256"
   ACCESS_TOKEN_EXPIRE_MINUTES: 15
   REFRESH_TOKEN_EXPIRE_DAYS: 7
   ENV: "development"
   ```

5. **Initialize Database & Seed:**
   Ensure you have a PostgreSQL server running locally, created a database named `pharmacy` matching your `DATABASE_URL`, and then run the seeder:
   ```bash
   python scripts/seed.py
   ```

6. **Start the FastAPI server:**
   ```bash
   uvicorn app.main:app --reload
   ```
   * The API docs will be active at `http://localhost:8000/docs`.

---

## 📱 Frontend Setup (Flutter)

1. **Navigate to the Flutter project directory:**
   ```bash
   cd flutter_pharmacy
   ```

2. **Get Flutter packages:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   Ensure you have a device connected (or a Windows build environment ready) and run:
   * **Windows Desktop:**
     ```bash
     flutter run -d windows
     ```
   * **Android / iOS:**
     ```bash
     flutter run
     ```

---

## 🔑 Default Credentials & App Onboarding

### Clean Seeding Details
When the database is first initialized, the seeder automatically sets up:
* The core roles (`admin`, `pharmacist`, `cashier`, `manager`).
* Platform-wide permissions catalog.
* **A single clean Administrator account:**
  * **Username:** `admin`
  * **Password:** `admin`

### Onboarding Steps
1. **First-time Open:** On first launch, the Flutter client will show an onboarding popup asking for the **API Server Connection URL**.
2. **Configure Host:** Enter your API endpoint (e.g. `http://localhost:8000` or the hosting server IP).
3. **Login:** Once connected, the app will route you to the login screen. You can log in using:
   * **Username:** `admin`
   * **Password:** `admin`
4. **Changing API Settings:** You can modify the API connection URL anytime by pressing the **Settings gear icon** in the top-left corner of the Login Screen.
