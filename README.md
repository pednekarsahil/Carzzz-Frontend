🚗 Carzzz
A Modern Car Rental Platform Built with Flutter

📱 About The Project
Carzzz is a feature-rich, modern car rental mobile application built with Flutter. This repository contains the complete frontend mobile application for the Carzzz car rental ecosystem, offering seamless car booking, real-time vehicle tracking, and an intuitive user experience.

✨ Key Features
🚗 Browse and search available vehicles

📍 Real-time vehicle location tracking

📅 Easy booking and reservation system

👤 User authentication and profile management

💳 Secure payment integration

📊 Booking history and trip management

🛠️ Tech Stack
Frontend: Flutter (Dart)

Backend: FastAPI (Python)

Database: MongoDB

Authentication: Firebase Admin

Real-time Updates: Socket.IO

📋 Prerequisites
Before you begin, ensure you have the following installed:

Flutter SDK (Latest version)

Android Studio with Flutter plugin

Visual Studio Code (Recommended for backend)

Python 3.8+

MongoDB (Local or Atlas)

🚀 Getting Started
Step 1: Create a New Flutter Project
Open Android Studio

Click on "New Flutter Project"

Select "Flutter Application"

Configure your project:

Project Name: carzzz

SDK Location: (Automatically detected)

Save Location: Choose your preferred directory

Click "Finish" and wait for the project to build

Step 2: Add the Source Code
Navigate to your project directory: carzzz/

Replace the lib/ folder with the one provided in this repository

Copy all Dart files from the source lib/ folder

Paste them into your project's lib/ folder

Ensure all assets (images, fonts, etc.) are properly placed in the assets/ directory

Step 3: Set Up the Backend
Open Visual Studio Code

Navigate to the backend folder:

text
cd carzzz/backend
Install the required Python libraries:

bash
pip install fastapi==0.104.1 uvicorn[standard]==0.24.0 python-multipart==0.0.6 pymongo==4.6.0 motor==3.3.2 python-dotenv==1.0.0 passlib[bcrypt]==1.7.4 python-jose[cryptography]==3.3.0 pydantic==2.5.0 pydantic-settings==2.1.0 email-validator==2.1.0 firebase-admin==6.4.0 python-socketio==5.10.0 python-engineio==4.8.0 aiofiles==23.2.1 cachetools==5.3.2 google-auth==2.26.0 google-cloud-firestore==2.14.0 grpcio==1.60.0 httpx==0.25.2
Note: If the system prompts you to install additional dependencies, simply follow the instructions or use:

bash
pip install -r requirements.txt
Step 4: Configure Environment Variables
Create a .env file in the backend/ directory

Add your configuration variables:

env
MONGODB_URI=your_mongodb_connection_string
FIREBASE_CREDENTIALS=path_to_firebase_credentials.json
SECRET_KEY=your_secret_key
Step 5: Run the Backend Server
In VS Code terminal (inside the backend/ folder), run:

bash
uvicorn server:app --reload --host 0.0.0.0 --port 8000
You should see output similar to:

text
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
Step 6: Run the Flutter Application
Open the carzzz/ project in Android Studio or VS Code

Connect an Android/iOS emulator or physical device

Run the application:

bash
flutter pub get
flutter run
📚 Resources for Flutter Development
If this is your first Flutter project, here are some helpful resources:

📖 Lab: Write your first Flutter app

📘 Cookbook: Useful Flutter samples

📕 Online Documentation - Tutorials, samples, and API reference

🎥 Flutter YouTube Channel

📄 License & Copyright
Copyright Notice
This project is proprietary and all rights are reserved. No permission is granted for any use, including commercial or non-commercial, beyond viewing and forking on GitHub as permitted by GitHub's Terms of Service.

text
© 2024 Carzzz. All Rights Reserved.
Important: This is NOT open-source software. The code is provided for viewing and reference purposes only.

🤝 Contributing
As this is a proprietary project, external contributions are not accepted at this time.

📞 Contact
For inquiries regarding licensing or collaboration:

📧 Email: sahildeepakpednekar2002@gmail.com



🙏 Acknowledgments
Built with ❤️ for car enthusiasts and riders

Special thanks to the Flutter and FastAPI communities

🏁 Happy Coding!
If you find any issues or have suggestions, please feel free to open an issue.
