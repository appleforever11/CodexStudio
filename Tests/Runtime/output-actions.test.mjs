import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';
import {revealOutput} from '../../Resources/DreamSkinRuntime/scripts/injector/output-actions.mjs';
test('Finder reveal permits only existing files confirmed by the native Outputs surface',async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'reveal-output-'));const file=path.join(root,'report $(no-shell).txt');await fs.writeFile(file,'test');let calls=[];
 try{
 const run=async(...args)=>{calls.push(args)};
 const allowed={evaluate:async()=>true}, denied={evaluate:async()=>false};
 for(const value of ['broken',JSON.stringify({path:'relative.txt'}),JSON.stringify({path:'https://example.com'}),JSON.stringify({path:file+'\0'})])assert.equal(await revealOutput(allowed,value,run),false);
 assert.equal(await revealOutput(denied,JSON.stringify({path:file}),run),false);
 assert.equal(await revealOutput(allowed,JSON.stringify({path:root}),run),false);
 assert.equal(await revealOutput(allowed,JSON.stringify({path:file}),run),true);
 assert.equal(calls.length,1);assert.deepEqual(calls[0].slice(0,2),['/usr/bin/open',['-R',file]]);
 }finally{await fs.rm(root,{recursive:true,force:true});}
});
