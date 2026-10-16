const $ = selector => document.querySelector(selector);
const state = { keys: [], generated: null };

async function request(url, options = {}) {
  const response = await fetch(url, { headers: { "Content-Type": "application/json", ...(options.headers || {}) }, ...options });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || "Falha na solicitação");
  return data;
}

function toast(message) { const el = $("#toast"); el.textContent = message; el.classList.add("show"); setTimeout(() => el.classList.remove("show"), 2800); }
function formatDate(value) { return value ? new Date(value).toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" }) : "Nunca"; }

async function load() {
  const [stats, keys] = await Promise.all([request("/api/stats"), request(`/api/keys?search=${encodeURIComponent($("#search").value)}`)]);
  $("#total").textContent = stats.stats.total; $("#active").textContent = stats.stats.active; $("#waiting").textContent = stats.stats.waiting; $("#revoked").textContent = stats.stats.revoked;
  state.keys = keys.keys; $("#keyCount").textContent = state.keys.length; renderKeys();
}

function renderKeys() {
  const rows = $("#keyRows"); rows.innerHTML = ""; $("#empty").classList.toggle("hidden", state.keys.length > 0);
  for (const key of state.keys) {
    const row = document.createElement("tr");
    const status = key.status === "active" ? "Ativa" : key.status === "expired" ? "Expirada" : "Revogada";
    row.innerHTML = `<td class="client"><strong>${escapeHtml(key.clientName)}</strong><code>${escapeHtml(key.key || `${key.prefix}...`)}</code></td><td><span class="badge ${key.status}">${status}</span></td><td>${escapeHtml(key.remaining)}<div class="bound">${key.expiresAt ? formatDate(key.expiresAt) : "sem expiração"}</div></td><td>${formatDate(key.lastSeen)}</td><td><div class="actions"><button class="action copy-key">Copiar</button><button class="action reset-key">Resetar HWID</button>${key.status === "active" ? '<button class="action danger revoke-key">Revogar</button>' : '<button class="action danger delete-key">Excluir</button>'}</div></td>`;
    row.querySelector(".copy-key").onclick = () => navigator.clipboard.writeText(key.key || "").then(() => toast("Key copiada"));
    row.querySelector(".reset-key").onclick = () => mutate(key.id, "reset", "HWID resetado");
    row.querySelector(".revoke-key")?.addEventListener("click", () => mutate(key.id, "revoke", "Key revogada"));
    row.querySelector(".delete-key")?.addEventListener("click", () => mutate(key.id, "delete", "Key excluída"));
    rows.appendChild(row);
  }
}

function escapeHtml(value) { return String(value ?? "").replace(/[&<>'"]/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[char])); }
async function mutate(id, action, message) { if ((action === "revoke" && !confirm("Revogar esta key?")) || (action === "delete" && !confirm("Excluir esta key definitivamente?"))) return; try { await request(`/api/keys/${id}/${action}`, { method: "POST", body: "{}" }); toast(message); await load(); } catch (error) { toast(error.message); } }

$("#loginForm").addEventListener("submit", async event => { event.preventDefault(); $("#loginError").textContent = ""; try { await request("/api/login", { method: "POST", body: JSON.stringify({ secret: $("#secret").value }) }); $("#loginView").classList.add("hidden"); $("#appView").classList.remove("hidden"); await load(); } catch { $("#loginError").textContent = "Senha incorreta ou serviço indisponível."; } });
$("#logout").onclick = async () => { await request("/api/logout", { method: "POST", body: "{}" }); location.reload(); };
$("#refresh").onclick = () => load().then(() => toast("Painel atualizado")).catch(error => toast(error.message));
$("#search").oninput = () => load().catch(() => {});
$("#generateForm").addEventListener("submit", async event => { event.preventDefault(); const button = event.target.querySelector("button"); button.disabled = true; try { const result = await request("/api/keys/generate", { method: "POST", body: JSON.stringify({ clientName: $("#clientName").value, duration: $("#duration").value }) }); state.generated = result.key.key; $("#generatedKey").textContent = state.generated; $("#generated").classList.remove("hidden"); $("#clientName").value = ""; toast("Nova key gerada"); await load(); } catch (error) { toast(error.message); } finally { button.disabled = false; } });
$("#copyGenerated").onclick = () => navigator.clipboard.writeText(state.generated).then(() => toast("Key copiada"));
$("#cleanup").onclick = async () => { if (!confirm("Excluir todas as keys expiradas e revogadas? Esta ação não pode ser desfeita.")) return; try { const result = await request("/api/keys/cleanup", { method: "POST", body: "{}" }); toast(`${result.removed} key(s) excluída(s)`); await load(); } catch (error) { toast(error.message); } };
