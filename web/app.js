const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'arca_admin';
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).catch(() => {});
}

let allowed = {};
let me = 0;
let data = { players: [], state: {} };
let selected = null;

const can = (action) => !!allowed[action];
const action = (name, payload = {}) => post('action', { action: name, data: payload });

// ---------------------------------------------------------------------
// Permissions: hide what this admin can't use
// ---------------------------------------------------------------------
function applyPerms(root = document) {
    $$('[data-action]', root).forEach((el) => el.classList.toggle('hidden', !can(el.dataset.action)));
    $$('[data-perm]', root).forEach((el) => el.classList.toggle('hidden', !can(el.dataset.perm)));
    $$('[data-form]', root).forEach((el) => el.classList.toggle('hidden', !can(FORMS[el.dataset.form]?.action)));
    $$('[data-self]', root).forEach((el) => el.classList.toggle('hidden', !can(el.dataset.self)));
}

// ---------------------------------------------------------------------
// Modal forms
// ---------------------------------------------------------------------
const options = (list, value = 'name', label = 'label') => list.map((o) => ({ value: o[value], label: o[label] }));

const FORMS = {
    announce: { action: 'announce', title: 'Send announcement', fields: [{ name: 'text', label: 'Message', placeholder: 'Server restart in 10 minutes' }] },
    tpcoords: { action: 'tpcoords', title: 'Teleport to coords', fields: [
        { name: 'paste', label: 'Paste x, y, z (or fill below)', placeholder: '215.3, -810.1, 30.7' },
        { name: 'x', label: 'X', type: 'number' }, { name: 'y', label: 'Y', type: 'number' }, { name: 'z', label: 'Z', type: 'number' },
    ], prepare: (v) => {
        const nums = (v.paste || '').match(/-?\d+(\.\d+)?/g);
        if (nums && nums.length >= 3) [v.x, v.y, v.z] = nums;
        return v;
    } },
    message: { action: 'message', title: 'Send private message', fields: [{ name: 'text', label: 'Message' }] },
    kick: { action: 'kick', title: 'Kick player', fields: [{ name: 'reason', label: 'Reason', placeholder: 'Kicked by staff' }] },
    ban: { action: 'ban', title: 'Ban player', fields: [
        { name: 'reason', label: 'Reason' },
        { name: 'hours', label: 'Length', type: 'select', options: () => [
            { value: 0, label: 'Permanent' }, { value: 1, label: '1 hour' }, { value: 24, label: '1 day' },
            { value: 72, label: '3 days' }, { value: 168, label: '1 week' }, { value: 720, label: '30 days' },
        ] },
    ] },
    setjob: { action: 'setjob', title: 'Set job', fields: [
        { name: 'job', label: 'Job', type: 'select', options: () => options(data.jobs || []), onChange: 'grade' },
        { name: 'grade', label: 'Grade', type: 'select', options: (v) => gradeOptions(data.jobs, v.job) },
    ] },
    setgang: { action: 'setgang', title: 'Set gang', fields: [
        { name: 'gang', label: 'Gang', type: 'select', options: () => options(data.gangs || []), onChange: 'grade' },
        { name: 'grade', label: 'Grade', type: 'select', options: (v) => gradeOptions(data.gangs, v.gang) },
    ] },
    givemoney: { action: 'givemoney', title: 'Give money', fields: [
        { name: 'type', label: 'Account', type: 'select', options: () => (data.moneyTypes || []).map((m) => ({ value: m, label: m })) },
        { name: 'amount', label: 'Amount', type: 'number' },
    ] },
    removemoney: { action: 'removemoney', title: 'Remove money', fields: [
        { name: 'type', label: 'Account', type: 'select', options: () => (data.moneyTypes || []).map((m) => ({ value: m, label: m })) },
        { name: 'amount', label: 'Amount', type: 'number' },
    ] },
    giveitem: { action: 'giveitem', title: 'Give item', fields: [
        { name: 'item', label: 'Item', type: 'select', options: () => (data.items || []).map((i) => ({ value: i.name, label: `${i.label} (${i.name})` })) },
        { name: 'count', label: 'Amount', type: 'number', value: 1 },
    ] },
    givevehicle: { action: 'spawnvehicle', title: 'Spawn vehicle for player', fields: [{ name: 'model', label: 'Model', placeholder: 'sultan' }] },
};

function gradeOptions(list, name) {
    const job = (list || []).find((j) => j.name === name) || (list || [])[0];
    return job ? job.grades.map((g) => ({ value: g.level, label: `${g.level} · ${g.name}` })) : [];
}

let modalSubmit = null;
const modal = $('#modal');

function closeModal() { modal.classList.add('hidden'); modalSubmit = null; }

function openModal(title, fieldsHtml, onSubmit, okLabel = 'Confirm') {
    $('#modal-title').textContent = title;
    $('#modal-fields').innerHTML = fieldsHtml;
    $('#modal-ok').textContent = okLabel;
    modalSubmit = onSubmit;
    modal.classList.remove('hidden');
    const first = $('#modal-fields input, #modal-fields select');
    if (first) first.focus();
}

function confirmBox(text, onYes) {
    openModal('Are you sure?', `<p>${esc(text)}</p>`, onYes);
}

function openForm(key, extra = {}) {
    const form = FORMS[key];
    if (!form) return;
    const values = {};
    const render = () => form.fields.map((f) => {
        if (f.type === 'select') {
            const opts = f.options(values);
            if (values[f.name] === undefined && opts.length) values[f.name] = opts[0].value;
            return `<label><span>${esc(f.label)}</span><select name="${f.name}">${opts.map((o) =>
                `<option value="${esc(o.value)}"${String(o.value) === String(values[f.name]) ? ' selected' : ''}>${esc(o.label)}</option>`).join('')}</select></label>`;
        }
        return `<label><span>${esc(f.label)}</span><input name="${f.name}" type="${f.type || 'text'}" step="any" placeholder="${esc(f.placeholder || '')}" value="${esc(values[f.name] ?? f.value ?? '')}"></label>`;
    }).join('');

    openModal(form.title, render(), () => {
        $$('#modal-fields [name]').forEach((el) => { values[el.name] = el.value; });
        const payload = form.prepare ? form.prepare({ ...values }) : { ...values };
        action(form.action, { ...extra, ...payload });
    });

    // selects that change other fields (job -> grades)
    $('#modal-fields').onchange = (e) => {
        const f = form.fields.find((x) => x.name === e.target.name);
        if (!f || !f.onChange) return;
        $$('#modal-fields [name]').forEach((el) => { values[el.name] = el.value; });
        values[f.onChange] = undefined;
        $('#modal-fields').innerHTML = render();
    };
}

$('#modal-box').addEventListener('submit', (e) => {
    e.preventDefault();
    const fn = modalSubmit;
    closeModal();
    if (fn) fn();
});
$('#modal-cancel').onclick = closeModal;

// ---------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------
$$('#tabs button').forEach((btn) => btn.addEventListener('click', () => {
    $$('#tabs button').forEach((b) => b.classList.toggle('active', b === btn));
    $$('.page').forEach((p) => p.classList.toggle('active', p.dataset.page === btn.dataset.tab));
}));

// ---------------------------------------------------------------------
// Generic buttons
// ---------------------------------------------------------------------
document.addEventListener('click', (e) => {
    const el = e.target.closest('button');
    if (!el || el.closest('#modal')) return;

    if (el.dataset.action) {
        const payload = el.dataset.data ? JSON.parse(el.dataset.data) : {};
        const run = () => action(el.dataset.action, payload);
        return el.dataset.confirm ? confirmBox(el.dataset.confirm, run) : run();
    }
    if (el.dataset.form) return openForm(el.dataset.form);
    if (el.dataset.self) return action(el.dataset.self, { id: me });
    if (el.dataset.copy) return post('copy', { kind: el.dataset.copy });
    if (el.dataset.weather) return action('weather', { weather: el.dataset.weather });
    if (el.dataset.time) return action('time', { hour: el.dataset.time, minute: 0 });
    if (el.dataset.model) return action('spawnvehicle', { model: el.dataset.model });
});

$('#close').onclick = () => post('close');
$('#veh-spawn').onclick = () => {
    const model = $('#veh-model').value.trim();
    if (model) action('spawnvehicle', { model });
};
$('#veh-model').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('#veh-spawn').click(); });
$('#time-set').onclick = () => action('time', { hour: $('#time-hour').value, minute: $('#time-minute').value || 0 });

// ---------------------------------------------------------------------
// Players
// ---------------------------------------------------------------------
function playerMatches(p, q) {
    if (!q) return true;
    return [p.id, p.name, p.charname, p.citizenid].some((v) => String(v ?? '').toLowerCase().includes(q));
}

function renderPlayers() {
    const q = $('#player-search').value.trim().toLowerCase();
    $('#player-list').innerHTML = data.players.filter((p) => playerMatches(p, q)).map((p) => `
        <button class="prow${p.id === selected ? ' active' : ''}" data-player="${p.id}">
            <span class="pid">${p.id}</span>
            <span class="pname"><b>${esc(p.charname || p.name)}</b><small>${esc(p.loaded ? `${p.name} · ${p.job}` : `${p.name} · not loaded in`)}</small></span>
            ${p.dead ? '<span class="badge dead">Down</span>' : ''}${p.rank ? `<span class="badge">${esc(p.rank)}</span>` : ''}
        </button>`).join('') || '<div class="empty">No players</div>';
    $('#player-count').textContent = data.players.length;
}

$('#player-search').addEventListener('input', renderPlayers);
$('#player-list').addEventListener('click', (e) => {
    const row = e.target.closest('[data-player]');
    if (!row) return;
    selected = Number(row.dataset.player);
    renderPlayers();
    renderDetail();
});

const PLAYER_ACTIONS = [
    { title: 'Movement', items: [
        { action: 'tpto', icon: 'fa-person-walking-arrow-right', label: 'Go to' },
        { action: 'bring', icon: 'fa-person-walking-arrow-loop-left', label: 'Bring' },
        { action: 'sendback', icon: 'fa-clock-rotate-left', label: 'Send back' },
        { action: 'spectate', icon: 'fa-eye', label: 'Spectate' },
        { action: 'freeze', icon: 'fa-snowflake', label: 'Freeze / unfreeze' },
    ] },
    { title: 'Health', items: [
        { action: 'heal', icon: 'fa-heart', label: 'Heal' },
        { action: 'revive', icon: 'fa-heart-pulse', label: 'Revive' },
        { action: 'kill', icon: 'fa-skull', label: 'Kill', danger: true, confirm: 'Kill this player?' },
    ] },
    { title: 'Character', needsLoaded: true, items: [
        { form: 'setjob', icon: 'fa-briefcase', label: 'Set job' },
        { form: 'setgang', icon: 'fa-people-group', label: 'Set gang' },
        { form: 'givemoney', icon: 'fa-money-bill-wave', label: 'Give money' },
        { form: 'removemoney', icon: 'fa-money-bill-transfer', label: 'Remove money' },
        { form: 'giveitem', icon: 'fa-box-open', label: 'Give item' },
        { action: 'openinventory', icon: 'fa-suitcase', label: 'Open inventory' },
        { action: 'clothing', icon: 'fa-shirt', label: 'Clothing menu' },
        { action: 'clearinventory', icon: 'fa-trash-can', label: 'Clear inventory', danger: true, confirm: 'Delete everything in their inventory?' },
        { form: 'givevehicle', icon: 'fa-car', label: 'Spawn vehicle for them' },
    ] },
    { title: 'Moderation', items: [
        { form: 'message', icon: 'fa-message', label: 'Message' },
        { form: 'kick', icon: 'fa-door-open', label: 'Kick', danger: true },
        { form: 'ban', icon: 'fa-gavel', label: 'Ban', danger: true },
    ] },
];

function renderDetail() {
    const p = data.players.find((x) => x.id === selected);
    const box = $('#player-detail');
    if (!p) {
        box.innerHTML = '<div class="empty"><i class="fa-solid fa-user"></i>Select a player</div>';
        return;
    }
    const money = (v) => (v === undefined ? '-' : `$${Number(v).toLocaleString()}`);
    const info = [
        ['Steam / FiveM name', p.name], ['Citizen ID', p.citizenid || '-'], ['Ping', `${p.ping} ms`],
        ['Job', p.job || '-'], ['Gang', p.gang || '-'], ['Health', `${Math.max(0, p.health - 100)} · Armor ${p.armor}`],
        ['Cash', money(p.cash)], ['Bank', money(p.bank)], ['Staff', p.rank || '-'],
    ];
    box.innerHTML = `
        <div class="d-head"><span class="pid">${p.id}</span><div><h1>${esc(p.charname || p.name)}</h1>
            <small>${p.loaded ? '' : 'In character selection · '}${p.dead ? 'Down' : 'Alive'}</small></div></div>
        <div class="info">${info.map(([k, v]) => `<div><span>${esc(k)}</span><b>${esc(v)}</b></div>`).join('')}</div>
        ${PLAYER_ACTIONS.filter((g) => !g.needsLoaded || p.loaded).map((g) => {
            const items = g.items.filter((i) => can(i.action || FORMS[i.form].action));
            if (!items.length) return '';
            return `<h2>${g.title}</h2><div class="grid">${items.map((i) => `
                <button class="tile${i.danger ? ' danger' : ''}" ${i.action ? `data-paction="${i.action}"` : `data-pform="${i.form}"`}${i.confirm ? ` data-pconfirm="${esc(i.confirm)}"` : ''}>
                    <i class="fa-solid ${i.icon}"></i>${esc(i.label)}</button>`).join('')}</div>`;
        }).join('')}`;
}

$('#player-detail').addEventListener('click', (e) => {
    const el = e.target.closest('button');
    if (!el || selected === null) return;
    const id = selected;
    if (el.dataset.paction) {
        const run = () => action(el.dataset.paction, { id });
        return el.dataset.pconfirm ? confirmBox(el.dataset.pconfirm, run) : run();
    }
    if (el.dataset.pform) openForm(el.dataset.pform, { id });
});

// ---------------------------------------------------------------------
// Rendering the rest
// ---------------------------------------------------------------------
const pad = (n) => String(n).padStart(2, '0');

function formatUptime(s) {
    const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
    return d ? `${d}d ${h}h` : h ? `${h}h ${m}m` : `${m}m`;
}

function renderStatic() {
    $('#weather-list').innerHTML = (data.weatherTypes || []).map((w) =>
        `<button class="chip" data-weather="${esc(w)}">${esc(w.charAt(0) + w.slice(1).toLowerCase())}</button>`).join('');
    $('#quick-vehicles').innerHTML = (data.quickVehicles || []).map((v) =>
        `<button class="chip" data-model="${esc(v.model)}">${esc(v.label)}</button>`).join('');
}

function renderBans() {
    const list = data.bans || [];
    $('#ban-list').innerHTML = list.length ? list.map((b) => `
        <div class="trow"><span class="grow"><b>${esc(b.name)}</b> <small>· ${esc(b.reason)} · by ${esc(b.by)} · ${b.expire === 0 ? 'permanent' : `until ${new Date(b.expire * 1000).toLocaleString()}`}</small></span>
        <button class="mini danger" data-unban="${b.id}">Unban</button></div>`).join('') : '<div class="trow"><small>No active bans</small></div>';
}

function renderResources() {
    const q = $('#res-search').value.trim().toLowerCase();
    $('#res-list').innerHTML = (data.resourceList || []).filter((r) => !q || r.name.toLowerCase().includes(q)).map((r) => `
        <div class="trow"><span class="grow">${esc(r.name)}</span><span class="state ${esc(r.state)}">${esc(r.state)}</span>
        ${r.state === 'started'
            ? `<button class="mini" data-res="restart" data-name="${esc(r.name)}">Restart</button><button class="mini danger" data-res="stop" data-name="${esc(r.name)}">Stop</button>`
            : `<button class="mini" data-res="start" data-name="${esc(r.name)}">Start</button>`}</div>`).join('');
}

$('#res-search').addEventListener('input', renderResources);
$('#res-list').addEventListener('click', (e) => {
    const el = e.target.closest('[data-res]');
    if (!el) return;
    const run = () => action('resources', { name: el.dataset.name, op: el.dataset.res });
    el.dataset.res === 'stop' ? confirmBox(`Stop ${el.dataset.name}?`, run) : run();
});
$('#ban-list').addEventListener('click', (e) => {
    const el = e.target.closest('[data-unban]');
    if (el) confirmBox('Remove this ban?', () => action('unban', { banId: Number(el.dataset.unban) }));
});

function renderToggles() {
    const state = { ...(data.state || {}), ...(data.world ? { freeze: data.world.freeze, blackout: data.world.blackout } : {}) };
    $$('[data-toggle]').forEach((el) => el.classList.toggle('on', !!state[el.dataset.toggle]));
    $$('[data-weather]').forEach((el) => el.classList.toggle('on', data.world && el.dataset.weather === data.world.weather));
}

function render(next) {
    const hadStatic = data.weatherTypes;
    data = { ...data, ...next };
    if (!hadStatic || next.weatherTypes) renderStatic();

    const s = data.server || {};
    $('#server-name').textContent = s.name || 'Server';
    $('#s-players').textContent = `${data.players.length} / ${s.maxPlayers || '?'}`;
    $('#s-uptime').textContent = formatUptime(s.uptime || 0);
    $('#s-weather').textContent = data.world ? data.world.weather : 'Off';
    $('#s-time').textContent = data.world ? `${pad(data.world.time.h)}:${pad(data.world.time.m)}` : '--:--';

    renderPlayers();
    if (selected !== null && !data.players.some((p) => p.id === selected)) selected = null;
    // don't rebuild the detail while a dialog is open over it
    if (modal.classList.contains('hidden')) renderDetail();
    renderBans();
    renderResources();
    renderToggles();
    applyPerms();
}

// ---------------------------------------------------------------------
// Messages from Lua
// ---------------------------------------------------------------------
window.addEventListener('message', (e) => {
    const { action: type, data: payload } = e.data || {};
    if (type === 'open') {
        allowed = payload.allowed || {};
        me = payload.self;
        $('#rank').textContent = payload.rank || 'Staff';
        $('#admin').classList.remove('hidden');
        applyPerms();
    } else if (type === 'close') {
        $('#admin').classList.add('hidden');
        closeModal();
    } else if (type === 'data') {
        render(payload);
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!modal.classList.contains('hidden')) return closeModal();
    post('close');
});
