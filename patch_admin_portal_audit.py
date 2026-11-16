import os

file_path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\web_admin_portal.html"
index_path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\index.html"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Update the table row generation for payments & audit events
old_map = """            payBody.innerHTML = payments.map(p => {
              const st = (p.status || 'pending').toLowerCase();
              let badge = '<span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-600">PENDING</span>';

              if (st === 'captured' || st === 'success') {
                badge = '<span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">SUCCESS</span>';
                successCount++;
                totalRevenue += (p.amount_paise / 100);
              } else if (st === 'cancelled') {
                badge = '<span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-200">CANCELLED</span>';
                cancelledCount++;
              } else if (st === 'failed') {
                badge = '<span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">FAILED</span>';
                failedCount++;
              }

              const candName = (p.students && p.students.full_name) ? p.students.full_name : 'M. Manoj';
              const candDistrict = (p.students && p.students.district) ? p.students.district : 'Ranipet';
              const testAttended = p.test_id || 'TNPSC / UPSC Timed Practice Mock';
              const paymentMode = p.payment_mode || 'UPI / Netbanking';

              return `
                <tr class="hover:bg-slate-50 transition">
                  <td class="p-3.5 font-mono text-xs font-bold text-slate-900">${p.razorpay_order_id || p.razorpay_payment_id || p.id}</td>
                  <td class="p-3.5">
                    <div class="font-bold text-slate-900">${candName}</div>
                    <div class="text-[11px] font-medium text-emerald-600">📍 ${candDistrict}</div>
                  </td>
                  <td class="p-3.5 font-semibold text-slate-900">${testAttended}</td>
                  <td class="p-3.5 font-medium text-slate-700">
                    <span class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-slate-100 text-slate-800 rounded-md text-[11px] font-bold">
                      <i class="fa-solid fa-building-columns text-[10px] text-slate-600"></i>
                      ${paymentMode}
                    </span>
                  </td>
                  <td class="p-3.5 font-black text-slate-900 font-mono">₹${(p.amount_paise / 100).toFixed(2)}</td>
                  <td class="p-3.5">${badge}</td>
                  <td class="p-3.5 text-xs text-slate-500 font-mono">${new Date(p.created_at).toLocaleString()}</td>
                </tr>
              `;
            }).join('');"""

new_map = """            payBody.innerHTML = payments.map(p => {
              const st = (p.status || 'pending').toLowerCase();
              const isAuditEvent = st === 'audit_event';

              let badge = '<span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-600">PENDING</span>';

              if (isAuditEvent) {
                badge = '<span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-purple-50 text-purple-700 border border-purple-200">EXAM SWITCHED</span>';
              } else if (st === 'captured' || st === 'success') {
                badge = '<span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">SUCCESS</span>';
                successCount++;
                totalRevenue += (p.amount_paise / 100);
              } else if (st === 'cancelled') {
                badge = '<span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-200">CANCELLED</span>';
                cancelledCount++;
              } else if (st === 'failed') {
                badge = '<span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">FAILED</span>';
                failedCount++;
              }

              const candName = (p.students && p.students.full_name) ? p.students.full_name : 'M. Manoj';
              const candDistrict = (p.students && p.students.district) ? p.students.district : 'Ranipet';
              
              let testAttended = p.test_id || 'TNPSC / UPSC Timed Practice Mock';
              let paymentMode = p.payment_mode || 'UPI / Netbanking';
              let orderText = p.razorpay_order_id || p.razorpay_payment_id || p.id;

              if (isAuditEvent) {
                testAttended = 'Stream Switch: UPSC ⇄ TNPSC';
                paymentMode = 'System Activity';
              }

              const rowBg = isAuditEvent ? 'bg-purple-50/40 hover:bg-purple-50/70' : 'hover:bg-slate-50';

              return `
                <tr class="${rowBg} transition">
                  <td class="p-3.5 font-mono text-xs font-bold ${isAuditEvent ? 'text-purple-900' : 'text-slate-900'}">${orderText}</td>
                  <td class="p-3.5">
                    <div class="font-bold text-slate-900">${candName}</div>
                    <div class="text-[11px] font-medium text-emerald-600">📍 ${candDistrict}</div>
                  </td>
                  <td class="p-3.5 font-semibold text-slate-900">${testAttended}</td>
                  <td class="p-3.5 font-medium text-slate-700">
                    <span class="inline-flex items-center gap-1.5 px-2.5 py-1 ${isAuditEvent ? 'bg-purple-100 text-purple-800' : 'bg-slate-100 text-slate-800'} rounded-md text-[11px] font-bold">
                      <i class="${isAuditEvent ? 'fa-solid fa-arrows-split-up-and-left' : 'fa-solid fa-building-columns'} text-[10px]"></i>
                      ${paymentMode}
                    </span>
                  </td>
                  <td class="p-3.5 font-black text-slate-900 font-mono">${isAuditEvent ? '—' : '₹' + (p.amount_paise / 100).toFixed(2)}</td>
                  <td class="p-3.5">${badge}</td>
                  <td class="p-3.5 text-xs text-slate-500 font-mono">${new Date(p.created_at).toLocaleString()}</td>
                </tr>
              `;
            }).join('');"""

text = text.replace(old_map, new_map)

# 2. Add an Exam Switch Audit Table or update security activity console to explicitly show candidate stream switches
console_init = """      <div id="auditLogConsole" class="h-28 overflow-y-auto space-y-1 font-mono text-xs text-slate-600 bg-slate-50 p-3 rounded-lg border border-slate-200">
        <div>[SYSTEM] Admin console loaded. Security monitoring initialized.</div>
      </div>"""

console_with_table = """      <div id="auditLogConsole" class="h-36 overflow-y-auto space-y-1 font-mono text-xs text-slate-600 bg-slate-50 p-3 rounded-lg border border-slate-200">
        <div>[SYSTEM] Admin console loaded. Real-time candidate exam switch tracking initialized.</div>
      </div>"""

text = text.replace(console_init, console_with_table)

# 3. In loadAdminData, automatically populate the auditLogConsole with historical switch events
old_after_data = """          renderCharts(successCount, cancelledCount, failedCount, upscCount, tnpscCount);
        }"""

new_after_data = """          renderCharts(successCount, cancelledCount, failedCount, upscCount, tnpscCount);

          // Populate real-time exam switch activities into Security Activity Log
          const switchEvents = payments.filter(p => (p.status || '').toLowerCase() === 'audit_event');
          switchEvents.forEach(ev => {
            const cName = (ev.students && ev.students.full_name) ? ev.students.full_name : 'Candidate';
            const dist = (ev.students && ev.students.district) ? ev.students.district : 'Ranipet';
            const t = new Date(ev.created_at).toLocaleTimeString();
            logAudit(`EXAM SWITCH DETECTED: [${cName} (${dist})] ${ev.razorpay_order_id} at ${new Date(ev.created_at).toLocaleString()}`);
          });
        }"""

text = text.replace(old_after_data, new_after_data)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

with open(index_path, "w", encoding="utf-8") as f:
    f.write(text)

print("SUCCESS: web_admin_portal.html and index.html updated with Exam Switch Audit Tracker!")

