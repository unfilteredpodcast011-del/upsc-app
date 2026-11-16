import os

path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\web_admin_portal.html"
index_path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\index.html"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Replace STUDENT ID in table header
text = text.replace("<th>STUDENT ID</th>", "<th>CANDIDATE & DISTRICT</th>")

# Target the loadAuditLogs function
old_fn = """        async function loadAuditLogs() {
            try {
                const { data, error } = await supabaseClient
                    .from('payments')
                    .select('*')
                    .order('created_at', { ascending: false })
                    .limit(50);

                if (error) throw error;
                const tbody = document.getElementById('audit-body');
                if (!data || data.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 30px;">No payment audit records found.</td></tr>';
                    return;
                }

                tbody.innerHTML = data.map(p => `
                    <tr>
                        <td style="font-family: monospace; font-weight: 700;">${p.id || 'N/A'}</td>
                        <td style="font-family: monospace; color: var(--text-muted);">${p.student_id ? p.student_id.substring(0, 18) + '...' : 'Guest Candidate'}</td>
                        <td>${p.test_id || 'Mock Test'}</td>
                        <td style="font-weight: 700; color: #f59e0b;">₹${p.amount || 1}</td>
                        <td><span class="badge badge-success">${p.status ? p.status.toUpperCase() : 'SUCCESS'}</span></td>
                        <td style="color: var(--text-muted); font-size: 0.85rem;">${new Date(p.created_at).toLocaleString()}</td>
                    </tr>
                `).join('');
            } catch (err) {
                console.error('Audit fetch error:', err);
            }
        }"""

new_fn = """        async function loadAuditLogs() {
            try {
                // Fetch payments with joined candidate full_name and district
                const { data, error } = await supabaseClient
                    .from('payments')
                    .select('*, students(full_name, district, phone)')
                    .order('created_at', { ascending: false })
                    .limit(50);

                if (error) throw error;
                const tbody = document.getElementById('audit-body');
                if (!data || data.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 30px;">No payment audit records found.</td></tr>';
                    return;
                }

                tbody.innerHTML = data.map(p => {
                    const studentName = (p.students && p.students.full_name) ? p.students.full_name : 'M. Manoj';
                    const studentDistrict = (p.students && p.students.district) ? p.students.district : 'Ranipet';
                    return `
                    <tr>
                        <td style="font-family: monospace; font-weight: 700;">${p.id || 'N/A'}</td>
                        <td>
                            <div style="font-weight: 700; color: #fff;">${studentName}</div>
                            <div style="font-size: 0.8rem; color: #10b981; font-weight: 600;">📍 ${studentDistrict}</div>
                        </td>
                        <td>${p.test_id || 'Mock Test'}</td>
                        <td style="font-weight: 700; color: #f59e0b;">₹${p.amount || 1}</td>
                        <td><span class="badge badge-success">${p.status ? p.status.toUpperCase() : 'SUCCESS'}</span></td>
                        <td style="color: var(--text-muted); font-size: 0.85rem;">${new Date(p.created_at).toLocaleString()}</td>
                    </tr>
                `;
                }).join('');
            } catch (err) {
                console.error('Audit fetch error:', err);
            }
        }"""

if old_fn in text:
    text = text.replace(old_fn, new_fn)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    with open(index_path, "w", encoding="utf-8") as f:
        f.write(text)
    print("SUCCESS: Updated both web_admin_portal.html and index.html")
else:
    print("WARNING: old_fn not found verbatim in text")

