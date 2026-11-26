# 야르 07 계정 서버

아이디로 로그인해서 게임 진행 상황을 서버에도 저장해 두는 작은 서버입니다. Cloudflare Workers(무료 플랜)와 D1 데이터베이스에서 돕니다. 게임 쪽 코드는 [`godot/scripts/cloud.gd`](../godot/scripts/cloud.gd)입니다.

지금 돌고 있는 주소: `https://accounts.yarr07.workers.dev` (워커 이름 `accounts`, 계정의 workers.dev 이름 `yarr07`, D1 데이터베이스 `yarr07-accounts`, 아시아·태평양 지역). 게임 여러 판에 이 주소가 들어 있으므로 워커 이름과 workers.dev 이름은 바꾸지 않습니다(바꾸면 이미 나간 게임에서 로그인이 되지 않습니다).

## 무엇을 저장하나

- **아이디**: 플레이어가 지은 것. 영문 소문자·숫자·밑줄 3~16자. 이메일이나 이름은 받지 않습니다.
- **비밀번호의 해시**: 비밀번호 자체는 서버에 오지 않습니다. 게임이 비밀번호를 아이디와 함께 PBKDF2-HMAC-SHA256으로 100,000번 늘린 값(키)만 보내고, 서버는 그 키를 계정마다 다른 솔트와 서버의 비밀값(`PEPPER`)으로 한 번 더 해시해서 그 해시만 둡니다. 데이터베이스만으로는 키도 비밀번호도 알아낼 수 없습니다.
- **복구 코드의 해시**: 가입할 때 한 번 보여 주는 16자 코드(`XXXX-XXXX-XXXX-XXXX`). 비밀번호를 잊었을 때 새 비밀번호를 정하는 하나뿐인 방법이고, 쓰면 새 코드로 바뀝니다.
- **로그인한 기기의 토큰 해시**: 기기에는 토큰이, 서버에는 그 SHA-256만 있습니다. 180일 동안 쓰지 않으면 끝나고, 계정마다 8대까지입니다.
- **진행 상황**: 게임의 저장 내용(JSON, 16KB까지)과 몇 번째로 쓴 것인지(`rev`).
- **틀린 시도의 횟수**: 아이디별, 그리고 요청한 주소의 해시별(주소 자체는 두지 않음). 하루에 한 번 지난 것을 지웁니다.

## 주소

| 요청 | 하는 일 |
|---|---|
| `POST /register {id, key}` | 가입. 토큰과 복구 코드를 돌려줌 |
| `POST /login {id, key}` | 로그인. 토큰과 계정의 진행 상황을 돌려줌 |
| `POST /recover {id, recovery, key}` | 복구 코드로 새 비밀번호. 새 복구 코드를 돌려주고 모든 기기를 로그아웃 |
| `GET /save` | 계정의 진행 상황 |
| `PUT /save {data, base, force}` | 진행 상황 저장. `base`는 이 기기가 마지막으로 본 `rev`. 그 사이 다른 기기가 썼으면 409와 함께 지금 있는 것을 돌려줌. 플레이어가 고른 뒤에만 `force` |
| `POST /logout` | 이 기기의 로그인을 끝냄 |
| `POST /delete {key}` | 비밀번호를 다시 확인하고 계정과 진행 상황을 모두 지움 |

`/save`, `/logout`, `/delete`는 `Authorization: Bearer <토큰>`이 필요합니다.

틀린 시도 제한: 로그인은 아이디마다 15분에 10번·주소마다 40번, 복구 코드는 아이디마다 1시간에 5번·주소마다 20번, 가입은 주소마다 1시간에 20번. 넘으면 429와 기다릴 시간(초)을 돌려줍니다.

웹판은 브라우저가 다른 주소의 서버에 묻는 것이라, `wrangler.toml`의 `ORIGINS`에 적힌 페이지에서 온 요청에만 브라우저가 읽을 수 있는 답을 줍니다. 앱과 PC판은 해당이 없습니다.

## 시험

```bash
cd server
npm install
npm test                                        # 서버만: Cloudflare 런타임(workerd)과 진짜 D1로 33가지
GODOT=/path/to/godot node test/game.test.mjs    # 게임(godot/tests/cloud.tscn)이 이 서버에 실제 HTTP로 붙어서 가입·저장·로그인·충돌·복구·삭제
node test/web.test.mjs                          # 웹판을 Chromium에서 띄워 같은 서버에 붙임 (먼저 tools/build_godot.sh)
python3 test/live.py https://accounts.yarr07.workers.dev   # 실제로 돌고 있는 서버를 밖에서: 쓰고 버리는 계정 하나로 가입·저장·충돌·복구·CORS·삭제 (남기는 것 없음)
```

## 올리기

Cloudflare 계정과 API 토큰(Account · Workers Scripts · Edit, Account · D1 · Edit, Account · Account Settings · Read)이 필요합니다. 토큰과 계정 ID는 환경 변수로만 주고 파일에 적지 않습니다.

```bash
export CLOUDFLARE_API_TOKEN=...   CLOUDFLARE_ACCOUNT_ID=...
npx wrangler deploy                                         # 코드를 고친 뒤에는 이것만 (비밀값과 데이터베이스는 그대로)
```

처음 한 번(이미 해 둠): 계정의 workers.dev 이름을 `yarr07`로 정하고(Cloudflare가 저절로 붙이는 이름은 가입한 이메일에서 따오므로 미리 정함), 데이터베이스를 만들어 `schema.sql`을 넣고, 비밀값을 정했습니다.

```bash
npx wrangler d1 create yarr07-accounts --location apac      # 나온 database_id를 wrangler.toml에 적음
npx wrangler d1 execute yarr07-accounts --remote --command "$(grep -v '^--' schema.sql)"
openssl rand -hex 32 | npx wrangler secret put PEPPER       # 서버의 비밀값. 한 번만 정하고, 사본을 비공개 저장소에 둠
```

- `PEPPER`를 잃어버리거나 바꾸면 **누구도 비밀번호나 복구 코드로 로그인할 수 없게 됩니다**(이미 로그인해 둔 기기만 계속 됩니다). 공개 저장소에는 절대 넣지 않습니다.
- 서버 주소(`https://<worker>.<subdomain>.workers.dev`)는 `godot/scripts/cloud.gd`의 `BASE`에, 웹판이 열리는 주소는 `wrangler.toml`의 `ORIGINS`에 적습니다. `BASE`가 비어 있으면 게임에 계정이 보이지 않습니다.
- 무료 플랜 한도: 하루 요청 10만 건, 요청 하나에 CPU 10ms(그래서 비밀번호를 늘리는 느린 계산은 게임 쪽에서 합니다), D1은 하루 읽기 500만 행·쓰기 10만 행·저장 5GB.
