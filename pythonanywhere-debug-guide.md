# PythonAnywhere 500 Error Debug Guide

## 🚨 **500 Internal Server Error on PythonAnywhere**

### **Step 1: Check Error Logs**

1. **Go to your PythonAnywhere dashboard**
2. **Click on "Web" tab**
3. **Click on your web app**
4. **Scroll down to "Error log"**
5. **Look for the actual error message**

### **Step 2: Common Issues & Solutions**

#### **Issue 1: Database Connection Error**
```
Error: (2002, "Can't connect to server")
```
**Solution:**
- Check if your database is created in PythonAnywhere
- Verify database credentials in environment variables
- Make sure `USE_PYTHONANYWHERE=True` is set

#### **Issue 2: Missing Dependencies**
```
ModuleNotFoundError: No module named 'xxx'
```
**Solution:**
```bash
# In PythonAnywhere console
pip install -r requirements.txt
```

#### **Issue 3: Environment Variables Not Set**
**Solution:**
- Go to "Web" tab → Your web app
- Scroll to "Environment variables"
- Add these variables:
```
USE_PYTHONANYWHERE=True
DB_NAME=MarwanIssa$default
DB_USER=MarwanIssa$default
DB_HOST=MarwanIssa.mysql.pythonanywhere-services.com
DB_PASSWORD=your_mysql_password
DB_PORT=3306
SECRET_KEY=your-secret-key
DEBUG=False
ALLOWED_HOSTS=marwanissa.pythonanywhere.com
```

#### **Issue 4: Database Not Migrated**
**Solution:**
```bash
# In PythonAnywhere console
python manage.py migrate
```

### **Step 3: Debug Commands**

#### **Test Database Connection:**
```bash
python manage.py dbshell
```

#### **Check Django Configuration:**
```bash
python manage.py check
```

#### **Test API Endpoint:**
```bash
python manage.py shell
>>> from polls.views import PollListView
>>> from django.test import RequestFactory
>>> factory = RequestFactory()
>>> request = factory.post('/api/polls/')
>>> view = PollListView()
>>> response = view.post(request)
```

### **Step 4: Quick Fixes**

#### **Fix 1: Update Settings for PythonAnywhere**
Make sure your `settings.py` has:
```python
# In your settings.py
USE_PYTHONANYWHERE = config('USE_PYTHONANYWHERE', default=False, cast=bool)

if USE_PYTHONANYWHERE:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.mysql',
            'NAME': 'MarwanIssa$default',
            'USER': 'MarwanIssa$default',
            'HOST': 'MarwanIssa.mysql.pythonanywhere-services.com',
            'PASSWORD': '$enSie@200',
            'PORT': '3306',
            'OPTIONS': {
                'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
                'charset': 'utf8mb4',
            },
        }
    }
```

#### **Fix 2: Add Error Handling to Views**
```python
# In your views.py
import logging
logger = logging.getLogger(__name__)

class PollListView(generics.ListCreateAPIView):
    def post(self, request, *args, **kwargs):
        try:
            return super().post(request, *args, **kwargs)
        except Exception as e:
            logger.error(f"Error in PollListView.post: {e}")
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
```

### **Step 5: Test Your API**

#### **Test with curl:**
```bash
curl -X POST https://marwanissa.pythonanywhere.com/api/polls/ \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Poll", "description": "Test Description"}'
```

#### **Test with Python:**
```python
import requests

response = requests.post(
    'https://marwanissa.pythonanywhere.com/api/polls/',
    json={'title': 'Test Poll', 'description': 'Test Description'}
)
print(response.status_code)
print(response.text)
```

### **Step 6: Check PythonAnywhere Specific Issues**

#### **Static Files:**
- Make sure static files are collected: `python manage.py collectstatic --noinput`
- Check static files mapping in Web tab

#### **WSGI Configuration:**
- Verify your WSGI file is correct
- Check if all imports are working

#### **Database:**
- Ensure MySQL database exists
- Check if migrations are run
- Verify database permissions

### **Step 7: Enable Debug Mode (Temporarily)**

**⚠️ Only for debugging - don't use in production:**

```python
# In settings.py
DEBUG = True
ALLOWED_HOSTS = ['*']
```

This will show detailed error messages instead of generic 500 errors.

### **Step 8: Common PythonAnywhere Errors**

#### **Error: "No module named 'django'"
**Solution:** Install dependencies in virtual environment

#### **Error: "Database connection failed"
**Solution:** Check database credentials and connection

#### **Error: "Static files not found"
**Solution:** Run `python manage.py collectstatic --noinput`

#### **Error: "Permission denied"
**Solution:** Check file permissions and ownership

### **Step 9: Monitoring**

#### **Check Logs Regularly:**
```bash
# In PythonAnywhere console
tail -f /var/log/marwanissa.pythonanywhere.com.error.log
```

#### **Monitor Database:**
```bash
# Check database connection
python manage.py dbshell
```

### **Step 10: Final Checklist**

- [ ] Database created and migrated
- [ ] All dependencies installed
- [ ] Environment variables set
- [ ] Static files collected
- [ ] WSGI configuration correct
- [ ] Error logs checked
- [ ] API endpoint tested

## 🚀 **Quick Fix Commands**

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Run migrations
python manage.py migrate

# 3. Collect static files
python manage.py collectstatic --noinput

# 4. Create superuser
python manage.py createsuperuser

# 5. Test configuration
python manage.py check

# 6. Reload web app
# (Click reload button in PythonAnywhere Web tab)
```

## 📞 **Still Having Issues?**

1. **Check the error log first** - this will tell you exactly what's wrong
2. **Test locally** - make sure your code works locally
3. **Check PythonAnywhere documentation** - for platform-specific issues
4. **Contact PythonAnywhere support** - if it's a platform issue

The most important step is **checking the error log** - it will show you the exact error causing the 500 response.
