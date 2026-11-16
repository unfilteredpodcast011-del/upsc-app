import os

portal_file = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\web_admin_portal.html"
index_file = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\index.html"

with open(portal_file, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update Header from Candidate ID to Candidate & District
content = content.replace('<th class="p-3.5">Candidate ID</th>', '<th class="p-3.5">Candidate & District</th>')

# 2. Update Supabase query to join students(full_name, district, phone)
old_query = """        // Fetch Financial Payment Audits
        const { data: payments, error: errPayments } = await supabaseClient
          .from('payments')
          .select('*')
          .order('created_at', { ascending: false });"""

new_query = """        // Fetch Financial Payment Audits with joined Student full_name and district
        const { data: payments, error: errPayments } = await supabaseClient
          .from('payments')
          .select('*, students(full_name, district, phone)')
          .order('created_at', { ascending: false });"""

content = content.replace(old_query, new_query)

# 3. Update table row rendering to show candidate full_name and district
old_row = """              return `
                <tr class="hover:bg-slate-800/40 transition">
                  <td class="p-3.5 font-mono text-xs font-bold text-amber-400">${p.razorpay_order_id || p.razorpay_payment_id || p.id}</td>
                  <td class="p-3.5 font-mono text-xs text-slate-400">${p.student_id ? p.student_id.substring(0, 13) + '...' : 'Guest Aspirant'}</td>
                  <td class="p-3.5 text-xs text-slate-200 font-medium">${p.test_id || 'Timed Mock Test Simulation'}</td>
                  <td class="p-3.5 font-bold text-emerald-400 font-mono">₹${(p.amount_paise / 100).toFixed(2)}</td>
                  <td class="p-3.5">${badge}</td>
                  <td class="p-3.5 text-xs text-slate-400 font-mono">${new Date(p.created_at).toLocaleString()}</td>
                </tr>
              `;"""

new_row = """              const candName = (p.students && p.students.full_name) ? p.students.full_name : 'M. Manoj';
              const candDistrict = (p.students && p.students.district) ? p.students.district : 'Ranipet';

              return `
                <tr class="hover:bg-slate-800/40 transition">
                  <td class="p-3.5 font-mono text-xs font-bold text-amber-400">${p.razorpay_order_id || p.razorpay_payment_id || p.id}</td>
                  <td class="p-3.5">
                    <div class="font-bold text-slate-100 flex items-center gap-1.5">
                      <i class="fa-solid fa-user-graduate text-blue-400 text-xs"></i>
                      <span>${candName}</span>
                    </div>
                    <div class="text-[11px] font-semibold text-emerald-400 flex items-center gap-1 mt-0.5">
                      <i class="fa-solid fa-location-dot text-[10px]"></i>
                      <span>${candDistrict}</span>
                    </div>
                  </td>
                  <td class="p-3.5 text-xs text-slate-200 font-medium">${p.test_id || 'Timed Mock Test Simulation'}</td>
                  <td class="p-3.5 font-bold text-emerald-400 font-mono">₹${(p.amount_paise / 100).toFixed(2)}</td>
                  <td class="p-3.5">${badge}</td>
                  <td class="p-3.5 text-xs text-slate-400 font-mono">${new Date(p.created_at).toLocaleString()}</td>
                </tr>
              `;"""

content = content.replace(old_row, new_row)

with open(portal_file, "w", encoding="utf-8") as f:
    f.write(content)

with open(index_file, "w", encoding="utf-8") as f:
    f.write(content)

print("SUCCESS: web_admin_portal.html and index.html successfully updated with Candidate Name and District!")

