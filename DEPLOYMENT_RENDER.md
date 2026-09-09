# 🚀 Deploying Habit Tracker App Backend to Render (Free Tier)

Your FastAPI backend is now fully updated to run on **Render's Free Tier** and connect to your free cloud database on **Aiven MySQL**.

We have already successfully imported your MySQL schema from `ai_planner_db.sql` into the Aiven cloud database.

---

## 💾 Database Configuration Details

We have configured and imported your tables to the following **Aiven MySQL** cloud instance:

*   **Host:** `mysql-11a8ce02-maharabdulrehman5-e3c5.h.aivencloud.com`
*   **Port:** `18217`
*   **User:** `avnadmin`
*   **Password:** `[Set via DB_PASSWORD environment variable]`
*   **Database Name:** `defaultdb`
*   **SSL:** Required (enabled automatically in backend code)

---

## 🛠️ Deployment Steps

Follow these simple steps to deploy your backend to Render:

### STEP 1: Commit and Push Code to GitHub

Open PowerShell in your project root (`C:\Users\Abdul Rehman\Downloads\habit-tracker-app-main`) and push all the configuration files and the database fix to your GitHub repository:

```powershell
git add .
git commit -m "Configure backend for Render, Aiven MySQL, SSL, and import fixes"
git push origin main
```

*(If you are on a different branch, make sure to push that branch or merge to main.)*

---

### STEP 2: Create a Render Web Service

1. Go to your **Render Dashboard**: **[https://dashboard.render.com](https://dashboard.render.com)**
2. Click the **"New +"** button in the top right, and select **"Web Service"**.
3. Select **"Build and deploy from a Git repository"** and click **Next**.
4. Choose your `habit-tracker-app-main` repository from the list (if it's not connected, click "Connect repository").
5. Configure the Web Service settings as follows:

| Setting | Value |
| :--- | :--- |
| **Name** | `habit-tracker-backend` |
| **Region** | Select the region closest to you (e.g., `Singapore` or `Frankfurt`) |
| **Branch** | `main` |
| **Root Directory** | `backend` *(CRITICAL: Type `backend` so Render looks in the backend folder)* |
| **Runtime** | `Python 3` |
| **Build Command** | `pip install -r requirements.txt` |
| **Start Command** | `uvicorn main:app --host 0.0.0.0 --port $PORT` |
| **Instance Type** | `Free` |

---

### STEP 3: Add Environment Variables on Render

In the Render configuration, click the **"Environment"** tab on the left menu (or scroll down to environment variables) and click **"Add Environment Variable"** to add the following:

| Key | Value | Notes |
| :--- | :--- | :--- |
| `DB_HOST` | `mysql-11a8ce02-maharabdulrehman5-e3c5.h.aivencloud.com` | Aiven MySQL Host |
| `DB_PORT` | `18217` | Aiven MySQL Port |
| `DB_USER` | `avnadmin` | Aiven MySQL User |
| `DB_PASSWORD` | `[Your Aiven MySQL Password]` | Aiven MySQL Password |
| `DB_NAME` | `defaultdb` | Aiven MySQL Database Name |
| `GROQ_API_KEY` | *[Your Groq API Key]* | Get yours from console.groq.com |
| `SECRET_KEY` | *[Any long random string]* | For security/token signatures |
| `DEBUG` | `False` | Turn off debug mode in production |
| `PYTHON_VERSION` | `3.11` | Tells Render which Python version to run |

Click **"Save Changes"** at the bottom.

---

### STEP 4: Deploy and Verify

1. Render will automatically start the deployment build once saved.
2. Watch the logs in the console until you see:
   `==> Common start command detected: uvicorn main:app --host 0.0.0.0 --port $PORT`
   `==> Your service is live at https://habit-tracker-backend.onrender.com`
3. Click the live URL link or open it in a browser:
   `https://habit-tracker-backend.onrender.com/docs`
   You should see the FastAPI Interactive Swagger documentation!

---

### STEP 5: Update the Flutter App

Once the backend is live on Render, you need to update the base URL in your Flutter frontend app:

1. Open `frontend_app/lib/config/environment.dart` (or `api_config.dart`).
2. Update the production API endpoint to:
   `https://habit-tracker-backend.onrender.com`
3. Save the file and run `flutter run` on your mobile device/emulator.

---

## ⚠️ Notes on Render Free Tier

1. **Spin-down / Cold Starts:** Render free services spin down automatically after 15 minutes of inactivity. The first request after a spin-down takes 30–60 seconds to boot up.
2. **Ephemeral File System:** The free tier does not persist uploads. Profile pictures uploaded to the server will be lost during restarts/re-deployments. To prevent this in the future, integration with an external storage provider (like Cloudinary free tier) is recommended.
