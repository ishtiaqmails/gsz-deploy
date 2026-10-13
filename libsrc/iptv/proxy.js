'use strict';
/* Minimal SOCKS5 CONNECT tunnel (no deps). IPTV panels behind Cloudflare 403 datacenter IPs, so the
   catalog pull routes through a residential relay (e.g. the Tailscale phone running Every Proxy).
   Every Proxy's HTTP mode can choke on these panels (502), but its SOCKS mode tunnels raw TCP, which
   gets through — so we open a SOCKS tunnel to the panel and speak HTTP over it ourselves. */
const net = require('net');
const { URL } = require('url');

// socks5Connect(proxyUrl, destHost, destPort, ms) -> Promise<net.Socket> already connected to dest.
function socks5Connect(proxyUrl, destHost, destPort, ms) {
  return new Promise((resolve, reject) => {
    let px; try { px = new URL(proxyUrl); } catch (e) { return reject(new Error('bad_proxy')); }
    const s = net.connect({ host: px.hostname, port: parseInt(px.port, 10) || 1080 });
    let stage = 0, buf = Buffer.alloc(0);
    const done = (err, sock) => { clearTimeout(timer); s.removeListener('data', onData); s.removeListener('error', onErr); if (err) { try { s.destroy(); } catch (e) {} reject(err); } else resolve(sock); };
    const timer = setTimeout(() => done(new Error('socks_timeout')), ms || 25000);
    const onErr = (e) => done(e);
    const onData = (d) => {
      buf = Buffer.concat([buf, d]);
      if (stage === 0) {
        if (buf.length < 2) return;
        if (buf[0] !== 0x05 || buf[1] !== 0x00) return done(new Error('socks_no_auth'));
        stage = 1; buf = Buffer.alloc(0);
        const host = Buffer.from(destHost);
        s.write(Buffer.concat([Buffer.from([0x05, 0x01, 0x00, 0x03, host.length]), host, Buffer.from([(destPort >> 8) & 0xff, destPort & 0xff])]));
      } else if (stage === 1) {
        if (buf.length < 2) return;
        if (buf[1] !== 0x00) return done(new Error('socks_connect_' + buf[1]));
        // reply is 10+ bytes; once we've seen the success code the tunnel is open
        done(null, s);
      }
    };
    s.on('error', onErr);
    s.once('connect', () => s.write(Buffer.from([0x05, 0x01, 0x00]))); // VER, 1 method, NO-AUTH
    s.on('data', onData);
  });
}

function isSocks(proxyUrl) { return /^socks/i.test(String(proxyUrl || '')); }

module.exports = { socks5Connect, isSocks };
