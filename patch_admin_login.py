import os

path1 = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\web_admin_portal.html"
path2 = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\index.html"

with open(path1, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Update ADMIN_CREDENTIALS email and password
old_creds = """    // Admin Credentials
    const ADMIN_CREDENTIALS = {
      email: 'manojvip36@gmail.com',
      password: 'admin' // Default password, can be reset
    };"""

new_creds = """    // Admin Credentials
    const ADMIN_CREDENTIALS = {
      email: 'plantgreeninertiamanagement@gmail.com',
      password: 'Admin@0711'
    };"""

text = text.replace(old_creds, new_creds)

# 2. Update default input value in login form
text = text.replace('value="manojvip36@gmail.com"', 'value="plantgreeninertiamanagement@gmail.com"')
text = text.replace('manojvip36@gmail.com', 'plantgreeninertiamanagement@gmail.com')

# 3. Remove "Forgot password?" link from password label
old_pass_header = """        <div>
          <div class="flex justify-between items-center mb-1">
            <label class="text-xs font-bold uppercase tracking-wider text-slate-700">Password</label>
            <button type="button" onclick="showForgotPasswordView()" class="text-xs font-semibold text-slate-600 hover:text-black underline">
              Forgot password?
            </button>
          </div>
          <input 
            type="password" 
            id="adminPassword" 
            required
            placeholder="••••••••••••"
            class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-black focus:border-black transition"
          >
        </div>"""

new_pass_header = """        <div>
          <div class="mb-1">
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-700">Password</label>
          </div>
          <input 
            type="password" 
            id="adminPassword" 
            required
            placeholder="••••••••••••"
            class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-black focus:border-black transition"
          >
        </div>"""

text = text.replace(old_pass_header, new_pass_header)

# 4. Remove the Forgot Password form HTML completely
old_forgot_form = """      <!-- Forgot Password View -->
      <form id="forgotPasswordForm" onsubmit="handleForgotPassword(event)" class="hidden space-y-4">
        <div class="text-center mb-2">
          <h3 class="text-lg font-bold text-slate-900">Reset Admin Password</h3>
          <p class="text-xs text-slate-500 mt-1">Enter your registered email to receive a password reset link.</p>
        </div>

        <div>
          <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1">Admin Email</label>
          <input 
            type="email" 
            id="resetEmail" 
            required
            value="plantgreeninertiamanagement@gmail.com"
            placeholder="admin@test11.com"
            class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-black focus:border-black transition"
          >
        </div>

        <div id="resetFeedback" class="hidden p-3 rounded-xl text-xs"></div>

        <button 
          type="submit" 
          id="resetBtn"
          class="w-full py-2.5 px-4 bg-black hover:bg-slate-800 text-white font-bold text-sm rounded-xl transition"
        >
          Send Reset Link
        </button>

        <button 
          type="button" 
          onclick="showLoginView()" 
          class="w-full py-2 text-xs font-semibold text-slate-600 hover:text-black transition"
        >
          ← Back to Sign In
        </button>
      </form>"""

text = text.replace(old_forgot_form, "")

# 5. Simplify handleAdminLogin so it verifies strictly with ADMIN_CREDENTIALS
old_login_fn = """    async function handleAdminLogin(e) {
      e.preventDefault();
      const email = document.getElementById('adminEmail').value.trim();
      const pass = document.getElementById('adminPassword').value.trim();
      const errorBox = document.getElementById('loginError');

      errorBox.classList.add('hidden');

      // Check against stored or default password
      const storedPass = localStorage.getItem('test11_admin_pwd') || ADMIN_CREDENTIALS.password;

      if ((email.toLowerCase() === ADMIN_CREDENTIALS.email.toLowerCase()) && (pass === storedPass)) {
        sessionStorage.setItem('test11_admin_authenticated', 'true');
        document.getElementById('authOverlay').classList.add('hidden');
        logAudit(`Admin Manoj [${email}] successfully signed in.`);
        loadAdminData();
      } else {
        errorBox.textContent = 'Invalid administrator credentials. Access restricted.';
        errorBox.classList.remove('hidden');
        logAudit(`Failed login attempt for [${email}].`);
      }
    }"""

new_login_fn = """    async function handleAdminLogin(e) {
      e.preventDefault();
      const email = document.getElementById('adminEmail').value.trim();
      const pass = document.getElementById('adminPassword').value.trim();
      const errorBox = document.getElementById('loginError');

      errorBox.classList.add('hidden');

      if ((email.toLowerCase() === ADMIN_CREDENTIALS.email.toLowerCase()) && (pass === ADMIN_CREDENTIALS.password)) {
        sessionStorage.setItem('test11_admin_authenticated', 'true');
        document.getElementById('authOverlay').classList.add('hidden');
        logAudit(`Administrator [${email}] authenticated successfully.`);
        loadAdminData();
      } else {
        errorBox.textContent = 'Invalid administrator credentials. Access denied.';
        errorBox.classList.remove('hidden');
        logAudit(`Unauthorized login attempt for [${email}].`);
      }
    }"""

text = text.replace(old_login_fn, new_login_fn)

with open(path1, "w", encoding="utf-8") as f:
    f.write(text)

with open(path2, "w", encoding="utf-8") as f:
    f.write(text)

print("SUCCESS: web_admin_portal.html and index.html updated with Admin@0711 and removed forgot password!")

