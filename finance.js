export const currencies=['UAH','USD','EUR'];
export function minor(value){const s=String(value).trim().replace(',','.');if(!/^\d{1,10}(\.\d{1,2})?$/.test(s))throw Error('Введите сумму с точностью до двух знаков');const n=Math.round(Number(s)*100);if(!Number.isSafeInteger(n))throw Error('Слишком большая сумма');return n}
export function money(n,c='UAH'){return new Intl.NumberFormat('ru-RU',{style:'currency',currency:c}).format(n/100)}
export function balance(a,ts){return Number(a.opening_minor)+ts.filter(t=>t.account_id===a.id).reduce((s,t)=>s+(t.kind==='income'?1:-1)*Number(t.amount_minor),0)}
export function totals(ts,month,accounts,currency){const ids=new Set(accounts.filter(a=>a.currency===currency).map(a=>a.id));const rows=ts.filter(t=>t.date.startsWith(month)&&ids.has(t.account_id));return {rows,income:rows.filter(t=>t.kind==='income').reduce((s,t)=>s+Number(t.amount_minor),0),expense:rows.filter(t=>t.kind==='expense').reduce((s,t)=>s+Number(t.amount_minor),0)}}
export function csv(rows){return '\uFEFF'+rows.map(row=>row.map(v=>{let s=String(v??'');if(/^[=+\-@\t\r]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"'}).join(',')).join('\r\n')}
export function today(){const d=new Date();return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`}
