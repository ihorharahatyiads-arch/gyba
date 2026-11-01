import fs from 'node:fs/promises';
const assets=['index.html','app.js','finance.js','style.css','config.js','sw.js','icon.svg','icon-192.png','icon-512.png','manifest.webmanifest'];
await fs.mkdir('dist',{recursive:true});
for(const name of assets)await fs.copyFile(name,`dist/${name}`);
console.log(`Built Finflow: ${assets.length} public assets.`);
