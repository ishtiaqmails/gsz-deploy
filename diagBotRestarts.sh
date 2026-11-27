#!/usr/bin/env bash
# diagBotRestarts — why gszwabot restarts so much: uptime, memory, unstable restarts, exit reasons, error logs. READ-ONLY.
set +e
echo "### pm2 describe gszwabot (uptime / restarts / unstable / mem / exit) ###"
pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const p=JSON.parse(d).find(x=>x.name==='gszwabot');if(!p){console.log('(not found)');return;}const e=p.pm2_env||{};const up=e.pm_uptime?Math.round((Date.now()-e.pm_uptime)/1000):null;console.log('status:',e.status);console.log('uptime:',up!=null?(up+'s ('+Math.round(up/60)+'m / '+Math.round(up/3600)+'h)'):'?');console.log('restarts:',e.restart_time,' unstable_restarts:',e.unstable_restarts);console.log('mem:',p.monit&&p.monit.memory?Math.round(p.monit.memory/1048576)+'MB':'?',' cpu:',p.monit&&p.monit.cpu);console.log('exec_mode:',e.exec_mode,' node_args:',(e.node_args||[]).join(' '));console.log('max_memory_restart:',e.max_memory_restart||'(none)');console.log('exit_code:',e.exit_code,' restart on last:',e.axm_options&&e.axm_options);}catch(err){console.log('parse err',err.message);}});" 2>/dev/null
echo
echo "### error log tail (crashes / exceptions) ###"
pm2 logs gszwabot --nostream --err --lines 40 2>/dev/null | tail -30
echo
echo "### out log: recent connected/closed cycle (how often it cycles) ###"
pm2 logs gszwabot --nostream --out --lines 400 2>/dev/null | grep -iE "\[wabot\] connected as|\[wabot\] closed|restart|uncaught|unhandled|heap|out of memory|FATAL|Error:" | tail -30
echo
echo "### is it cycling right now? count 'connected as' in last 500 out-lines ###"
pm2 logs gszwabot --nostream --out --lines 500 2>/dev/null | grep -c "\[wabot\] connected as"
echo "### pm2 start args / script for gszwabot ###"
pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const p=JSON.parse(d).find(x=>x.name==='gszwabot');const e=p.pm2_env||{};console.log('script:',e.pm_exec_path);console.log('cwd:',e.pm_cwd);console.log('watch:',e.watch||false);console.log('autorestart:',e.autorestart);}catch(err){}});" 2>/dev/null
echo DONE
