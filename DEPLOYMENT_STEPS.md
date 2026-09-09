# Step-by-Step Deployment Guide

## 🎯 STEP 1: Create GitHub Account (If you don't have one)

### 1.1 Go to GitHub
1. Open your browser
2. Go to: **https://github.com**
3. Click **"Sign up"** (top right corner)

### 1.2 Create Account
1. Enter your email address
2. Create a password (strong password!)
3. Choose a username (e.g., `abdulrehman` or anything you like)
4. Verify you're human (solve the puzzle)
5. Click **"Create account"**

### 1.3 Verify Email
1. Check your email inbox
2. Find email from GitHub
3. Click the verification link
4. You're done! ✅

---

## 🎯 STEP 2: Create GitHub Repository

### 2.1 Create New Repository
1. Log in to GitHub
2. Click the **"+"** icon (top right)
3. Click **"New repository"**

### 2.2 Repository Settings
Fill in these details:

**Repository name:** `habit-tracker-app`

**Description:** `AI-powered habit tracker with voice commands and smart notifications`

**Visibility:** 
- ⚠️ Choose **"Private"** (IMPORTANT - your code contains API keys)

**Initialize repository:**
- ❌ **DO NOT** check "Add a README file"
- ❌ **DO NOT** check "Add .gitignore"
- ❌ **DO NOT** choose a license

### 2.3 Create Repository
1. Click **"Create repository"**
2. You'll see a page with setup instructions
3. **Keep this page open** - we'll use it in the next step

---

## 🎯 STEP 3: Push Your Code to GitHub

### 3.1 Open PowerShell
1. Press **Windows Key**
2. Type **"PowerShell"**
3. Click **"Windows PowerShell"**

### 3.2 Navigate to Your Project
Copy and paste this command (press Enter after):

```powershell
cd "C:\Users\Abdul Rehman\Desktop\habit"
```

### 3.3 Initialize Git
Run these commands one by one:

```powershell
# Initialize git repository
git init
```

Expected output: `Initialized empty Git repository...`

### 3.4 Add All Files
```powershell
# Add all files to git
git add .
```

This might take a few seconds. No output means success!

### 3.5 Create First Commit
```powershell
# Commit all files
git commit -m "Initial commit: Habit tracker app with voice and notifications"
```

Expected output: Shows files added, insertions, etc.

### 3.6 Connect to GitHub
**IMPORTANT:** Replace `YOUR_USERNAME` with your actual GitHub username!

```powershell
# Add GitHub as remote
git remote add origin https://github.com/YOUR_USERNAME/habit-tracker-app.git
```

Example: If your username is `abdulrehman`, use:
```powershell
git remote add origin https://github.com/abdulrehman/habit-tracker-app.git
```

### 3.7 Rename Branch to Main
```powershell
# Rename branch to main
git branch -M main
```

### 3.8 Push to GitHub
```powershell
# Push code to GitHub
git push -u origin main
```

**You'll be asked to log in:**
1. A window will pop up asking for GitHub credentials
2. Enter your GitHub username
3. For password, use a **Personal Access Token** (not your password)

**If you don't have a token:**
1. Go to: https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Name: `DigitalOcean Deployment`
4. Expiration: `90 days`
5. Check: `repo` (all repo permissions)
6. Click **"Generate token"**
7. **COPY THE TOKEN** (you won't see it again!)
8. Use this token as password in PowerShell

### 3.9 Verify Upload
1. Go back to your GitHub repository page
2. Refresh the page
3. You should see all your files! ✅

---

## ✅ Checkpoint

At this point, you should have:
- ✅ GitHub account created
- ✅ Repository created (`habit-tracker-app`)
- ✅ Code pushed to GitHub
- ✅ Can see your files on GitHub website

**Screenshot what you see and let me know when you're ready for the next step!**

---

## 🎯 NEXT STEP: DigitalOcean Setup

Once you confirm the above is complete, we'll move to:
1. Creating DigitalOcean account
2. Creating App Platform app
3. Connecting GitHub
4. Deploying!

**Take your time with each step. Let me know if you get stuck anywhere!**
