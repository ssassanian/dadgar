import os,subprocess,time,tempfile,re,sys,socket
from playwright.sync_api import sync_playwright
tmp=tempfile.mkdtemp();port=3917
env=dict(os.environ,NODE_ENV='test',DEV_SHOW_OTP='1',DATA_DIR=tmp,PORT=str(port),LOGIN_RL_MAX='500')
subprocess.run(['node','--disable-warning=ExperimentalWarning','scripts/seed-demo.js'],cwd='/home/claude/dadgar',env=env,capture_output=True)
srv=subprocess.Popen(['node','--disable-warning=ExperimentalWarning','server.js'],cwd='/home/claude/dadgar',env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
for _ in range(50):
    try: socket.create_connection(('127.0.0.1',port),timeout=.2).close();break
    except OSError: time.sleep(.1)
base=f'http://127.0.0.1:{port}'
res=[];
def ok(c,m): res.append((bool(c),m)); (None if c else print('  FAIL:',m))
with sync_playwright() as p:
    b=p.chromium.launch();ctx=b.new_context(viewport={'width':1440,'height':900});pg=ctx.new_page()
    errs=[];pg.on('pageerror',lambda e:errs.append('PAGEERR '+str(e)));pg.on('console',lambda m:errs.append(m.text) if m.type=='error' else None)
    pg.route('**/*',lambda r: r.continue_() if r.request.url.startswith(base) else r.abort())
    H=lambda:pg.evaluate('location.hash')
    def go(h): pg.evaluate("h=>{location.hash=h}",h);pg.wait_for_timeout(900)
    def toast(sub=''):
        for _ in range(50):
            for t in pg.query_selector_all('.ts'):
                x=t.inner_text()
                if sub in x: return x
            pg.wait_for_timeout(100)
        return ''
    def wait_hash(h,ms=4000):
        try: pg.wait_for_function("h=>location.hash===h",arg=h,timeout=ms)
        except Exception: pass
        pg.wait_for_timeout(250)
    pg.goto(base+'/');pg.wait_for_timeout(900)
    ok(pg.title().startswith('موسسه حقوقی'),'home loads under the strict CSP')
    ok(not pg.query_selector('#fln a[href="#/c"],#fln a[href^="#/c/"],#fln a[href="#/l"],#fln a[href^="#/l/"],#fln a[href="#/a"],#fln a[href^="#/a/"]'),'footer has no panel links')
    ok(pg.query_selector('#fln a[href="#/login"]') is not None,'footer still links to the login page')
    go('#/c');ok(H()=='#/login','unauthenticated visit to the client panel goes to login')
    go('#/a');ok(H()=='#/login','unauthenticated visit to the admin panel goes to login')
    # wrong password
    pg.fill('#lu','client');pg.fill('#lp','bad-password-1');pg.click('[data-lg]');ok('اشتباه' in toast('اشتباه'),'wrong password shows an error and stays on login')
    # real login + forced change
    pg.fill('#lp','Client#2026');pg.click('[data-lg]');wait_hash('#/c/profile')
    ok(H()=='#/c/profile','first login is forced to the profile page')
    ok(pg.query_selector('#dash .demo b') is not None and 'تغییر دهید' in pg.inner_text('#dc'),'forced-change notice is shown')
    ok(pg.evaluate("document.cookie")=='','session cookie is not readable from JavaScript (HttpOnly)')
    go('#/c/cases');ok(H()=='#/c/profile','other panel pages are blocked until the password is changed')
    pg.fill('#pc','Client#2026');pg.fill('#p1','short1');pg.fill('#p2','short1');pg.click('[data-pp]');ok('۱۰' in toast('۱۰'),'weak new password is refused')
    pg.fill('#p1','Mehr#Secure2026x');pg.fill('#p2','Mehr#Secure2026x');pg.click('[data-pp]');wait_hash('#/c')
    ok(H()=='#/c','after a strong password the dashboard opens');
    ok('مریم' in pg.inner_text('#sdb') and 'پنل مشتری' in pg.inner_text('#sdb'),'sidebar shows the user name and role')
    ok(pg.query_selector('#dc .card2.demo') is not None,'not-yet-connected panel pages are labelled as demo data')
    go('#/a');ok(H()=='#/c','a client cannot open the admin panel (redirected to own panel)')
    go('#/l/open');ok(H()=='#/l' or H()=='#/c','a client cannot open lawyer pages') 
    # logout
    pg.click('#sdb [data-lo]');pg.wait_for_timeout(700);ok(H()=='#/login','logout returns to login')
    go('#/c');ok(H()=='#/login','panel is closed again after logout')
    go('#/c/cases');ok(H()=='#/login' and True,'deep link requires login')
    # login again, deep link remembered
    pg.fill('#lu','client');pg.fill('#lp','Mehr#Secure2026x');pg.click('[data-lg]');wait_hash('#/c/cases')
    ok(H()=='#/c/cases','after login the user lands on the page they asked for')
    pg.click('#sdb [data-lo]');pg.wait_for_timeout(600)
    # SMS login
    go('#/login');pg.click('[data-ti="lg:1"]');pg.fill('#op','09170000001');pg.click('[data-oq]');t=toast('کد')
    m=re.search(r'(\d{6})',t);ok(m is not None,'SMS code request works (dev driver shows the code)')
    pg.fill('#oc',m.group(1));pg.click('#oc-w [data-ov]');wait_hash('#/c')
    ok(H()=='#/c' and 'کاربر' in pg.inner_text('#sdb'),'login with SMS code creates and opens a client account')
    pg.click('#sdb [data-lo]');pg.wait_for_timeout(600)
    # register
    go('#/login');pg.click('[data-ti="lg:2"]');pg.fill('#rn','سارا نمونه');pg.fill('#rp','09180000002');pg.fill('#rw','Reg#Pass2026x');pg.fill('#rw2','Reg#Pass2026x');pg.evaluate("document.querySelectorAll('.ts').forEach(e=>e.remove())");pg.click('[data-rg]');t=toast('آزمایشی')
    m=re.search(r'(\d{6})',t);ok(m is not None,'registration sends a code')
    pg.fill('#rc',m.group(1));pg.click('#rc-w [data-rv]');wait_hash('#/c');ok(H()=='#/c','registration finishes after phone verification (hash='+H()+' toasts='+str([x.inner_text() for x in pg.query_selector_all('.ts')])+')')
    pg.click('#sdb [data-lo]');pg.wait_for_timeout(600)
    # admin
    go('#/login');pg.fill('#lu','admin');pg.fill('#lp','Admin#2026');pg.click('[data-lg]');wait_hash('#/a/profile')
    ok(H()=='#/a/profile','admin first login goes to the profile page')
    ok(pg.query_selector('#sdb a[href="#/a/profile"]') is not None,'admin sidebar has a profile link')
    pg.fill('#pc','Admin#2026');pg.fill('#p1','Safe#Pass2026xy');pg.fill('#p2','Safe#Pass2026xy');pg.click('[data-pp]');wait_hash('#/a');ok(H()=='#/a','admin reaches the admin dashboard after changing the password')
    go('#/c');ok(H()=='#/a','admin is kept inside the admin panel')
    # sitemap has no panel links
    pg.click('#sdb [data-lo]');pg.wait_for_timeout(600);go('#/sitemap')
    ok(not pg.query_selector('#app a[href^="#/c/"],#app a[href^="#/l/"],#app a[href^="#/a/"]'),'sitemap page lists no panel pages')
    csp=[e for e in errs if 'Content Security Policy' in e or 'Refused' in e]
    other=[e for e in errs if e not in csp and 'Failed to load resource' not in e]
    ok(not csp,'no CSP violations in the browser console'+(' '+str(csp[:2]) if csp else ''))
    ok(not other,'no JavaScript errors'+(' '+str(other[:2]) if other else ''))
    b.close()
srv.terminate()
print(f"{sum(1 for c,_ in res if c)} passed, {sum(1 for c,_ in res if not c)} failed")
