## v1.25.2 (2026-06-19)

### Fix

- **deps**: pin flutter_native_splash to ^2.4.7 for SDK compatibility

## [1.28.0](https://github.com/howard86/masquerade/compare/v1.27.0...v1.28.0) (2026-07-30)


### Features

* **a11y:** add semantics labels + haptics to bare icon tap targets ([9b21a5a](https://github.com/howard86/masquerade/commit/9b21a5a7853e9e95fe46c760223399f27068aef6))
* **a11y:** add Semantics to bare desktop tap targets ([4748b20](https://github.com/howard86/masquerade/commit/4748b209beec45065da8c4c0e29dc5f0f9598814))
* **a11y:** add Semantics to bare desktop tap targets ([184f465](https://github.com/howard86/masquerade/commit/184f4651d13359f1ab5f1af314526844931ed24f))
* **a11y:** announce color/uuid/cron parse errors via MqStatus ([2ac0f80](https://github.com/howard86/masquerade/commit/2ac0f80b5b5e5a293a847df22338b75d466a3eef))
* **a11y:** announce color/uuid/cron parse errors via MqStatus ([f9fa6af](https://github.com/howard86/masquerade/commit/f9fa6af4f9c13c2557c32762da6094d90b05e525))
* **a11y:** announce diff collapse + bare tap targets to screen readers ([b78c280](https://github.com/howard86/masquerade/commit/b78c280a069d064994093e27ba444aa630e45351))
* **a11y:** announce List quote-style chip as a selected toggle ([92988cd](https://github.com/howard86/masquerade/commit/92988cd044e56c9cc5d8286d8224ffe5e188d27c))
* **a11y:** announce List quote-style chip as a selected toggle ([8991092](https://github.com/howard86/masquerade/commit/8991092718a84acea02a4b18e714b9d10353a1f2))
* **a11y:** announce MqInput error text as a live region ([40149dc](https://github.com/howard86/masquerade/commit/40149dc92d03035ad41d67a2aa6638e3fbefadc9))
* **a11y:** announce MqInput error text as a live region ([673addf](https://github.com/howard86/masquerade/commit/673addfb055d3a99db45f74e82082654c759e6db))
* **a11y:** announce MqStatus errors via a Semantics live region ([002b993](https://github.com/howard86/masquerade/commit/002b9937f326fdd592315fe57f1b902e7d9088ec))
* **a11y:** announce MqStatus errors via a Semantics live region ([a139f7f](https://github.com/howard86/masquerade/commit/a139f7f42224695905e61cf7e5f49d58e752c277))
* **a11y:** announce parse errors via MqStatus in five tool bodies ([9fa8327](https://github.com/howard86/masquerade/commit/9fa8327466bc79d891fe06f647eac707f3ed151b))
* **a11y:** announce parse errors via MqStatus in five tool bodies ([e3731f3](https://github.com/howard86/masquerade/commit/e3731f3cdcc615c60919e5a057a332366ee27f80))
* **a11y:** button Semantics for the shared MqChip ([cbf4f72](https://github.com/howard86/masquerade/commit/cbf4f72527862ec90ba615eadcf45424e1b95ab5))
* **a11y:** button Semantics for the shared MqChip ([9e98fc7](https://github.com/howard86/masquerade/commit/9e98fc74bf361d4d3f3fb8bea34bd701ea305497))
* **a11y:** exclude barrier/drag GestureDetectors from semantics ([219fd3b](https://github.com/howard86/masquerade/commit/219fd3b5b886a330fc8bbb8b14ad3197b56cd183))
* **a11y:** exclude barrier/drag GestureDetectors from semantics ([b829635](https://github.com/howard86/masquerade/commit/b8296350bed7a0f4a9465c06f0b621432179acfc))
* **a11y:** extend Copy-all to Hash, JWT, and bps tool bodies ([23037b6](https://github.com/howard86/masquerade/commit/23037b622083298b125a0e055a41f06df65d3ba9))
* **a11y:** extend Copy-all to Hash, JWT, and bps tool bodies ([4ba3610](https://github.com/howard86/masquerade/commit/4ba36108105f6b399d4f8ad0e32014dff5dadc70))
* **a11y:** extend Copy-all to uuid, x509, and cron bodies ([46f6acb](https://github.com/howard86/masquerade/commit/46f6acbd26dc2118d0c3975068867c54b303d5cb))
* **a11y:** extend Copy-all to uuid, x509, and cron bodies ([d9cc691](https://github.com/howard86/masquerade/commit/d9cc691ed2b0f22c31381901e2dd416927469c0e))
* **a11y:** keyboard navigation for the desktop icon grid ([dbffc29](https://github.com/howard86/masquerade/commit/dbffc2913896b65ba0a95dce6bbd74caff6cfd7d))
* **a11y:** keyboard navigation for the desktop icon grid ([ebe7dbe](https://github.com/howard86/masquerade/commit/ebe7dbe9bdbd7a5eb58ca49f2310a22633acb9e1))
* **a11y:** name the cell in MqMonoCell's copy-button semantics ([18cdd65](https://github.com/howard86/masquerade/commit/18cdd65648a971b20f10719f58c947ff65bd68bf))
* **a11y:** name the cell in MqMonoCell's copy-button semantics ([534c83e](https://github.com/howard86/masquerade/commit/534c83edf48c072422e9f29bbd6d16be77e2da13))
* **a11y:** respect Reduce Motion in copy-confirmation feedback ([4c2fa0e](https://github.com/howard86/masquerade/commit/4c2fa0e72ce949d7cb5534f88f879bc9f796fc31))
* **a11y:** respect Reduce Motion in copy-confirmation feedback ([72a001a](https://github.com/howard86/masquerade/commit/72a001aa89db4c3311c18870bd8a056f07f45360))
* **a11y:** Semantics for diff collapse control + remaining bare tap targets ([7b88edd](https://github.com/howard86/masquerade/commit/7b88edd3d48fded4548ab8df085645643ec35188))
* **a11y:** Semantics labels + haptics on bare icon tap targets ([b1656a5](https://github.com/howard86/masquerade/commit/b1656a5a75b99f2768746fcc29f730e521ff2c4a))
* **a11y:** Semantics labels for desktop dock tiles ([a8ce1f4](https://github.com/howard86/masquerade/commit/a8ce1f435e76cc4e4691823239a591110e7dda94))
* **a11y:** Semantics labels for desktop dock tiles ([2154c24](https://github.com/howard86/masquerade/commit/2154c2498706ca11a7456ea41e6d58c03fd3ce24))
* **a11y:** Semantics(button) for Timestamp picker rows ([1659d03](https://github.com/howard86/masquerade/commit/1659d0332393a0313e86030af084ef8d764006b5))
* **a11y:** Semantics(button) for Timestamp picker rows ([0cfd8ec](https://github.com/howard86/masquerade/commit/0cfd8eca962f226b6f9ef1fcd09164dae209f77b))
* add artifact detection models ([6c80e22](https://github.com/howard86/masquerade/commit/6c80e22b9ec0ec557500a485935c66c181623a42))
* add artifact detection models ([f824f85](https://github.com/howard86/masquerade/commit/f824f854ecaabb333689d9b615e5f10e4b901dbd))
* add case converter ([1c33afb](https://github.com/howard86/masquerade/commit/1c33afb7b0ced688be354eab8e96b76b997d82c2))
* add case converter ([ad20cd1](https://github.com/howard86/masquerade/commit/ad20cd16f6c7cb8408d85f73fb17332c3000852b))
* add categorized library favorites ([a98eb14](https://github.com/howard86/masquerade/commit/a98eb14d75df616616f20ba76c00131efaec2326))
* add categorized library favorites ([9a8c926](https://github.com/howard86/masquerade/commit/9a8c926117247a92b755f52e1b3c8bf49b334365))
* add Copy-all action for multi-output tools (Number Base, Color) ([5e54dc4](https://github.com/howard86/masquerade/commit/5e54dc493bc17e213dcc9d9cac1f9d266abd25e3))
* add Copy-all action to Timestamp and IP tools ([6a96d6b](https://github.com/howard86/masquerade/commit/6a96d6b4fdc16d65260fe73454ffebb96e3a4273))
* add CSV and TSV converter ([8f9b691](https://github.com/howard86/masquerade/commit/8f9b69134929382f98c1ea98f55690a9f490048a))
* add CSV and TSV converter ([58e5d56](https://github.com/howard86/masquerade/commit/58e5d564d508cd9917680c466dd5f0070e7a5862))
* add environment config inspector ([df02e34](https://github.com/howard86/masquerade/commit/df02e342fad136f0731c1b76f40fc14d171bac04))
* add environment config inspector ([7bf151d](https://github.com/howard86/masquerade/commit/7bf151de62a420dc1113afc1f5bb6706d26329ce))
* add focused iOS app intents ([aa96175](https://github.com/howard86/masquerade/commit/aa961751a22844025a77a6382e2da2e6ee6d66e2))
* add focused iOS app intents ([4456704](https://github.com/howard86/masquerade/commit/44567045ee3279d5116b223fecbeab94696ff080))
* add Generator tool (password / token / UUID) ([255b63b](https://github.com/howard86/masquerade/commit/255b63b9cdad33b46669a40d81763b298b6547a0))
* add Generator tool (password / token / UUID) ([25c9cb8](https://github.com/howard86/masquerade/commit/25c9cb812bd1c95a5a0d86ff4d2cd0dc3336e057))
* add Hash tool (MD5 / SHA-1 / SHA-256 / SHA-512) ([4f0541b](https://github.com/howard86/masquerade/commit/4f0541b7c8c33018c5978a3ada852ed40e5fa5c0))
* add Hash tool (MD5 / SHA-1 / SHA-256 / SHA-512) ([43e903e](https://github.com/howard86/masquerade/commit/43e903ee9ca1ee8fbcad0d4950fff01dba7cdf91))
* add HTTP request inspector ([5442d52](https://github.com/howard86/masquerade/commit/5442d5269010cb2c74c1cefb17a241d5908d2586))
* add HTTP request inspector ([c125b30](https://github.com/howard86/masquerade/commit/c125b30ff2330450c205b7ca3cc38d0b4ba882f6))
* add iOS share inbox extension ([9b24475](https://github.com/howard86/masquerade/commit/9b244758a67901b0951cca662a81b1a9a7fff7d8))
* add iOS share inbox extension ([fdbf61a](https://github.com/howard86/masquerade/commit/fdbf61a92920a2e0c1b67750361588edbfe84288))
* add IP / CIDR parser tool ([8c2f742](https://github.com/howard86/masquerade/commit/8c2f74202d3ed5ab5992191422b7798c13407507))
* add IP / CIDR parser tool ([f20104a](https://github.com/howard86/masquerade/commit/f20104a0e393313e384eaadd27f6a805ae5d6c7e)), closes [#50](https://github.com/howard86/masquerade/issues/50)
* add JWT decoder tool ([ca6a672](https://github.com/howard86/masquerade/commit/ca6a6721a6ca8385aa2e39e57163a68417e47772)), closes [#49](https://github.com/howard86/masquerade/issues/49)
* add JWT decoder tool ([#49](https://github.com/howard86/masquerade/issues/49)) ([e3ccaea](https://github.com/howard86/masquerade/commit/e3ccaeab515ea7fb1c91b02a5abc263bbca7c0c1))
* add List tool (split/join list formatter) ([562c783](https://github.com/howard86/masquerade/commit/562c783d27456fd04e2f7dac632cb4b40bd0837e))
* add log and stack inspector ([85ae5b7](https://github.com/howard86/masquerade/commit/85ae5b7dc9993af286fd62369512e63922b374c4))
* add log and stack inspector ([ec16e50](https://github.com/howard86/masquerade/commit/ec16e506e054101607a85b67f82c55dd08bdc049))
* add Markdown preview tool ([b4bf020](https://github.com/howard86/masquerade/commit/b4bf0207bb5ef1f6710a8ae91a0d2d1496ee8cb5))
* add Markdown preview tool ([2450455](https://github.com/howard86/masquerade/commit/2450455d061186565382cc7c8a5a917dffe13da9))
* add Math expression evaluator tool ([0edb05d](https://github.com/howard86/masquerade/commit/0edb05dddc6e82e19989d05a8a4cfc7566a98ef7))
* add mobile session step actions ([98e7566](https://github.com/howard86/masquerade/commit/98e75666a8c2e29fffe557b423e112bd24c9ace1))
* add mobile session step actions ([05106e3](https://github.com/howard86/masquerade/commit/05106e3b91eed3bd09b900ec012724afaaab60b0))
* add mobile workbench library activity shell ([6fcf1e8](https://github.com/howard86/masquerade/commit/6fcf1e8096b488554e12b682afc25353efe2a46c))
* add mobile workbench library activity shell ([0a46af2](https://github.com/howard86/masquerade/commit/0a46af272e0ca00e8f5b165f052763a46b8c6f61))
* add mobile workflow sessions ([b757750](https://github.com/howard86/masquerade/commit/b7577503c595481ff552d1729b59ee768b893601))
* add mobile workflow sessions ([390bd98](https://github.com/howard86/masquerade/commit/390bd98f96da11abfad2237e7356e5296aa79077))
* add persisted work session models ([d073a52](https://github.com/howard86/masquerade/commit/d073a523a8eb1adb73a6098300373ffbbff0a089))
* add persisted work session models ([93e4f7f](https://github.com/howard86/masquerade/commit/93e4f7fb19a425a490bc36ca1f45f7c3ec662095))
* add privacy and acknowledgements screens ([1c531d5](https://github.com/howard86/masquerade/commit/1c531d58c5a497ebde6d4accfebdac4d6dfe5798))
* add privacy and acknowledgements screens ([d037412](https://github.com/howard86/masquerade/commit/d037412299561ff3110c7209158f87f3dd8046f3))
* add ranked artifact detection ([c46033c](https://github.com/howard86/masquerade/commit/c46033cef71b991cd3894f0285dae9bc62ecd7dc))
* add ranked artifact detection ([a423d0b](https://github.com/howard86/masquerade/commit/a423d0bfbadbf5d6f888cd5dff382553edbb1197))
* add recursive artifact inspector ([b1f6ff6](https://github.com/howard86/masquerade/commit/b1f6ff679ae14445356fde4195feb7d4b73335d1))
* add recursive artifact inspector ([1d491ed](https://github.com/howard86/masquerade/commit/1d491edb8f50f8eb36266c6859e66998c773d4b0))
* add regex tester ([60329ed](https://github.com/howard86/masquerade/commit/60329edf762c8524a2f6ebb177c3554e7c9c047f))
* add regex tester ([e28630a](https://github.com/howard86/masquerade/commit/e28630a40394de280c90ee3d929123f5e0e7ac69))
* add reusable saved workflows ([d0ef43d](https://github.com/howard86/masquerade/commit/d0ef43d49e6c2453483154b7c4183369fcbbb989))
* add reusable saved workflows ([096fc18](https://github.com/howard86/masquerade/commit/096fc185396f360d965d9126ae560ad15b732641))
* add safe Spotlight shortcut discovery ([cbd5399](https://github.com/howard86/masquerade/commit/cbd5399a8191c9629676e04f55244852acb6a333))
* add safe Spotlight shortcut discovery ([d064305](https://github.com/howard86/masquerade/commit/d064305d82d70a88d6ed015ca6f428f173a9aece))
* add typed catalog routing metadata ([211aa97](https://github.com/howard86/masquerade/commit/211aa9763ecfe11508468766d458971e56bd30e8))
* add typed catalog routing metadata ([27cb7bd](https://github.com/howard86/masquerade/commit/27cb7bdb5d5f96d6f8f828010be2b101263441fd))
* add Unicode string inspector ([7e7822d](https://github.com/howard86/masquerade/commit/7e7822d640278fc86e995d82a4c0e578d325a3a0))
* add Unicode string inspector ([3dfa978](https://github.com/howard86/masquerade/commit/3dfa978a9699dac1bd942cc6eb353e02c45d8608))
* add URL encode/decode + query-string tool ([d938fae](https://github.com/howard86/masquerade/commit/d938fae53e37a14084d2e34f1318d248c99baf49))
* add URL encode/decode + query-string tool ([61feb38](https://github.com/howard86/masquerade/commit/61feb38dd4b611735ce5f860e166527c0e43a041))
* add UUID / ULID parser tool ([0ecaece](https://github.com/howard86/masquerade/commit/0ecaeceedc14a8519a1f06d23d5d821d18d82798))
* add UUID / ULID parser tool ([74dc728](https://github.com/howard86/masquerade/commit/74dc728d8e9308e91a45e2fccb2f1336cf710fe6)), closes [#47](https://github.com/howard86/masquerade/issues/47)
* add workbench capture states ([1c1c34c](https://github.com/howard86/masquerade/commit/1c1c34c4b175af3f5e3bfd6fbf02e4aedb3b58a0))
* add workbench capture states ([b2ce5e5](https://github.com/howard86/masquerade/commit/b2ce5e50150fd4d5c9204f6a1f3d5401756ee6ae))
* add X.509 certificate inspector ([a188f0c](https://github.com/howard86/masquerade/commit/a188f0c8e95a2a5ccd3a3b732ce1b68cb58cd6f8))
* add X.509 certificate inspector ([4d8ca69](https://github.com/howard86/masquerade/commit/4d8ca693b9c1272e7e378a3ab260977819b14e0d))
* add YAML / TOML conversion to the JSON tool ([ca75ad1](https://github.com/howard86/masquerade/commit/ca75ad1cf04b5f9e8c2e78eb37b164eed59fd623))
* apply Magic Box design handoff (6 items in one PR) ([505244e](https://github.com/howard86/masquerade/commit/505244eceab9633d9f620df45e4eaac8d0aab0e6))
* apply Magic Box design handoff (6 items in one PR) ([0e1e6d8](https://github.com/howard86/masquerade/commit/0e1e6d8a769d4f55f7fb9c47b30adf6d218eec9c))
* arrow-key 2D traversal for the desktop icon grid ([d3aa480](https://github.com/howard86/masquerade/commit/d3aa48028a9c1f018dfb43016693116d69673414))
* arrow-key 2D traversal for the desktop icon grid ([fac3aee](https://github.com/howard86/masquerade/commit/fac3aee6d9868aa89fb5dd51410c36c104378ad8))
* Base64 image preview + byte-delta at canvas width (Direction B phase 7) ([8d1acc4](https://github.com/howard86/masquerade/commit/8d1acc49e745c312d5959ab7600bc22a3a0a8c11))
* bps pinned-baseline delta at canvas width (Direction B phase 7) ([b00b587](https://github.com/howard86/masquerade/commit/b00b587634a1c1147a699b7fc68aa55d5b2fc205))
* **brand:** add hammer+quill marketing render ([98cb1d2](https://github.com/howard86/masquerade/commit/98cb1d213526afafe160bcf7d2247cc7fdb92d45))
* **brand:** add SVG mark sources + rasterization pipeline ([1535121](https://github.com/howard86/masquerade/commit/153512159128f2638b550c6a16d3b0efe6ddb684))
* **brand:** redesign monogram to bracketed hammer+quill ([a352fac](https://github.com/howard86/masquerade/commit/a352fac01c8b52af8549e2a66bfe3f9e86029bb7))
* bring the desktop OS to native macOS ([f7d3507](https://github.com/howard86/masquerade/commit/f7d350732333b17925ee1ff7c30cc291f4eb5a27))
* Bytes hexdump view + Latin-1/UTF-16LE decode (Direction B phase 7) ([18f5168](https://github.com/howard86/masquerade/commit/18f516813d9c24d0c944e2d3a11853b8d7534ec8))
* **bytes:** add Bytes utility tool ([c236a74](https://github.com/howard86/masquerade/commit/c236a746c58709a9203f365868d66eb5bacca717))
* **bytes:** add Bytes utility tool + extract MqEmptyHint ([b0c58e5](https://github.com/howard86/masquerade/commit/b0c58e53f357a26381ad9e5a4d19a12008d607d3))
* canonical-hub link engine (ADR 0001) — model + controller API ([391fded](https://github.com/howard86/masquerade/commit/391fded6c6e5665fd5c05e7750dcaf7442c1aa66))
* canonical-hub live links — Base64↔JSON flagship (Direction B) ([a497dc3](https://github.com/howard86/masquerade/commit/a497dc301a8ad94a58900e979f067487b3090120))
* Color session palette strip (Direction B phase 7) ([3a8e16f](https://github.com/howard86/masquerade/commit/3a8e16fdfca66acfd305019f670c70b8ca20af7d))
* Copy-all action for multi-output tools (Number Base, Color) ([075de98](https://github.com/howard86/masquerade/commit/075de9851f0e1e596ee60c29b167d820b655aa8d))
* Copy-all action for Timestamp and IP tools ([fe6f29c](https://github.com/howard86/masquerade/commit/fe6f29c313d72288d12f1b653f3002986345c5fe))
* Cron 7-day fire strip at canvas width (Direction B phase 7) ([372e755](https://github.com/howard86/masquerade/commit/372e755a983ab51641ec6f781d66b14a3e7623a6))
* **cron:** add Cron tool body and register in catalog ([66f637c](https://github.com/howard86/masquerade/commit/66f637c77ab3b823d0fa8529075e86c5bacbc862))
* **cron:** add POSIX 5-field and natural-language parsers ([9a153e1](https://github.com/howard86/masquerade/commit/9a153e19b33d70b82435941693c55e28d6aa4c16))
* **cron:** bidirectional cron tool with POSIX 5-field + natural language ([a33aca5](https://github.com/howard86/masquerade/commit/a33aca59bfdc761a64f1c482d615023add616e5f))
* desktop multi-card canvas (Direction B) — canvas MVP ([#73](https://github.com/howard86/masquerade/issues/73)) ([aef36b7](https://github.com/howard86/masquerade/commit/aef36b7fc6d69ad6e53da599f00b4cf76ae511de))
* **desktop:** add persistent wallpaper controller state management ([2533236](https://github.com/howard86/masquerade/commit/2533236db70e61ac1bc6170b97f14fda8ebe2bbe))
* **desktop:** add right-click context menu and animate minimized window snapping ([02fcd70](https://github.com/howard86/masquerade/commit/02fcd701e615168293436b10f5be2d0681cad884))
* **desktop:** bound the shell into a height-capped, bordered window ([7a39cc9](https://github.com/howard86/masquerade/commit/7a39cc996700301b2f3db2ff1083a64642ff4107))
* **desktop:** cap and center the shell on wide displays ([36bf283](https://github.com/howard86/masquerade/commit/36bf2834aef5cf6c734c74f5a41f3547fe1a4cc9))
* **desktop:** desktop icon grid + Spotlight palette ([50e66bd](https://github.com/howard86/masquerade/commit/50e66bd7552015d1b30ad374d22afb0045d75935))
* **desktop:** desktop shell customizer, snapping, context menus, icon grid, and shortcuts HUD ([940dee5](https://github.com/howard86/masquerade/commit/940dee52c92308ef9eac99aff2dac2fdb5c0aad7))
* **desktop:** empty-state for Spotlight command palette ([546eba6](https://github.com/howard86/masquerade/commit/546eba6539431056a30777b28167e3870a920c25))
* **desktop:** empty-state for Spotlight command palette ([d38d084](https://github.com/howard86/masquerade/commit/d38d08446cc02028f15843e5b4326787f01c4964))
* **desktop:** enable native macOS shell ([fd51934](https://github.com/howard86/masquerade/commit/fd51934c9b4a8bba6f2a40053c5b14172cc8d2d5))
* **desktop:** full-bleed macOS-style shell (Phase 1) ([6a82c70](https://github.com/howard86/masquerade/commit/6a82c70d594758f652a82a18bc6ca2d952d4066f))
* **desktop:** History & Settings as system windows ([bef99d9](https://github.com/howard86/masquerade/commit/bef99d94b4709bf7ea1c0c87dcadbc863b54f58a))
* **desktop:** icon grid + Spotlight palette (Phase 2) ([0fa97d1](https://github.com/howard86/masquerade/commit/0fa97d1e6e3e9e19ff46689a666fc8e9c322373d))
* **desktop:** implement multi-directional resize handles, body tap to focus, and stateful traffic light hovers ([6aa4b79](https://github.com/howard86/masquerade/commit/6aa4b791853738cfa3dd85c635f11a7a1f4bd710))
* **desktop:** implement premium generative wallpaper styles ([3744609](https://github.com/howard86/masquerade/commit/37446090d12361743f5c7a40bd2b9e5b759b34d5))
* **desktop:** introduce tactile shortcuts HUD keycap modal ([d103e1f](https://github.com/howard86/masquerade/commit/d103e1fe7bdf16eca115239b8ff4b137abf7b754))
* **desktop:** replace sidebar with full-bleed macOS-style shell ([963cad6](https://github.com/howard86/masquerade/commit/963cad6110d06745ba50556f5e6e5791d275c730))
* **desktop:** structure right-aligned icon grid with spring bounce clicks ([f00b7f6](https://github.com/howard86/masquerade/commit/f00b7f628cc606592c59812e89a926f94d253ac7))
* **desktop:** support grabbable Y-clamping and multi-directional edge resizing in CanvasController ([4934d68](https://github.com/howard86/masquerade/commit/4934d68725ff1ee2227022507ffff42ee6505c68))
* **desktop:** window manager — traffic lights, z-order, min/max/snap, dock ([a9ee6b7](https://github.com/howard86/masquerade/commit/a9ee6b7eca92fbf4b45292ed708b7cc8603b92ce))
* **desktop:** wire multi-directional resizing and draw L-shaped orthogonal link lines ([2a70180](https://github.com/howard86/masquerade/commit/2a701809f776f87540fc8b15d14f7fc2edf8421c))
* Diff dual-pane default at canvas width (Direction B phase 7) ([eb0422a](https://github.com/howard86/masquerade/commit/eb0422a587c748cfb37f7731cc1648a3e4c2df07))
* Diff tool (text compare) ([bb24810](https://github.com/howard86/masquerade/commit/bb24810d2142f141e6b98e198388862249cc3a88))
* **diff:** add Diff tool — body, catalog entry, and icon ([a227730](https://github.com/howard86/masquerade/commit/a2277303ed626bd8390652373895c673c7533f6a)), closes [#60](https://github.com/howard86/masquerade/issues/60)
* **diff:** add Myers line/word diff parser ([74e043a](https://github.com/howard86/masquerade/commit/74e043a5245bdc4936eb5db38344e87c0be511b7))
* **diff:** scroll long diff lines horizontally ([75e338b](https://github.com/howard86/masquerade/commit/75e338bcfed08866c84afa75a44496eb2b3075aa))
* editable two-way query table for the URL tool ([a6c1a15](https://github.com/howard86/masquerade/commit/a6c1a155448f4ca678088f92d2fc8e9ae35cbb90))
* editable two-way query table for the URL tool ([031bad3](https://github.com/howard86/masquerade/commit/031bad32608560ddf243c94462f3cd38bf45db2c))
* **generator:** guarantee one char per enabled class + show entropy ([f8f36fd](https://github.com/howard86/masquerade/commit/f8f36fd2f38acfce70d3954c58616325e006a233))
* **generator:** guarantee one char per enabled class + show entropy ([21cf7a1](https://github.com/howard86/masquerade/commit/21cf7a19f6c81b2d1bf0cd174e427c8f2c49a5e1))
* grow AnimatedCopyIcon hit target to 44x44 ([512d9ab](https://github.com/howard86/masquerade/commit/512d9ab6904e7d1d093304a7ead780be4a5c54f8))
* grow AnimatedCopyIcon hit target to 44x44 ([45a4a59](https://github.com/howard86/masquerade/commit/45a4a598ba70cbb07b34fb9fce03ef369eccaf9d))
* grow MqMonoCell copy hit target to 44x44 (HIG) ([af0afb1](https://github.com/howard86/masquerade/commit/af0afb1607c8a7aa4903d021c50aab937f149621))
* grow MqMonoCell copy hit target to 44x44 (HIG) ([6113c16](https://github.com/howard86/masquerade/commit/6113c16a676e8b4727f07ca955b7f88705ce5172))
* **history:** dedupe consecutive same-tool same-input adds ([7935c4a](https://github.com/howard86/masquerade/commit/7935c4a4b67bba59acfed04069dea738d02fd89a))
* **home:** auto-expand single match, recents row, grid preview, long-press copy ([417e09d](https://github.com/howard86/masquerade/commit/417e09d75077ca4bf2187e04f4bab50fbbb9c61d))
* **home:** chip toggle + persistent body; remove Search tab ([df0e804](https://github.com/howard86/masquerade/commit/df0e804006cf8efd0de9d4e9873a88585f49e068))
* **home:** CompactPasteBar two-stage hero composer ([73aa108](https://github.com/howard86/masquerade/commit/73aa108f53f285d0129277335736092d6776d8c4))
* **home:** inline tool cards replace per-tile push navigation ([5951cad](https://github.com/howard86/masquerade/commit/5951cad4b14c4675444ce9bae5ed5d35936305da))
* **home:** inline tool cards with auto-expand, recents, cross-tool piping ([a74ba3e](https://github.com/howard86/masquerade/commit/a74ba3e3bacc80906f232957a45d25d3f1d0f714))
* **home:** redesign with hero paste + flat tool grid ([79e4e13](https://github.com/howard86/masquerade/commit/79e4e131bcedf895f34d9f834469663123af5913))
* **home:** rows act as chips; selecting one hides the rest ([4a054ba](https://github.com/howard86/masquerade/commit/4a054bae10aa579b673eb73d8dc357983c7aef23))
* **home:** ToolGridCard editorial grid tile ([574437b](https://github.com/howard86/masquerade/commit/574437bdb9afd9a28b5cc1426dad088366bf2a00))
* import external Workbench inputs ([8e9aa12](https://github.com/howard86/masquerade/commit/8e9aa12d0e1c5bc2b5cc6f295f046f41d6ca523a))
* import external Workbench inputs ([1bc229b](https://github.com/howard86/masquerade/commit/1bc229b166eb508e3ae0b3349f9a1f02cc1f089b))
* **input:** heuristic paste detection on MqInput via controller listener ([b17eea2](https://github.com/howard86/masquerade/commit/b17eea21c49e5b27d46c087a4e06a3101f6e6329))
* **input:** MqInput accepts external focus node ([3e934c7](https://github.com/howard86/masquerade/commit/3e934c7d4d1b294eb6aa0c8a17c102b794e9fd50))
* **ios:** regenerate AppIcon + LaunchImage for hammer+quill ([574d8aa](https://github.com/howard86/masquerade/commit/574d8aacd74f81f5753e667f35eeb52b80725a88))
* **ios:** regenerate AppIcon + LaunchImage from brand assets ([ca3fee6](https://github.com/howard86/masquerade/commit/ca3fee6498e1c66165a8271e1e94490e9b9ad8e7))
* JSON / YAML / TOML converter ([11dd854](https://github.com/howard86/masquerade/commit/11dd8542a8b121d277f48079e4745e6a3192bddc))
* JSON two-pane layout at canvas width (Direction B phase 7) ([30bb692](https://github.com/howard86/masquerade/commit/30bb692c3382dba0befe145aa54dd816fb81918d))
* List inline count + Diff-with action at canvas width (Direction B phase 7) ([9a92430](https://github.com/howard86/masquerade/commit/9a92430f9dcea2c56624e19f3611224615d8a25a))
* **list:** add List tool with split/join UI ([1a3e7af](https://github.com/howard86/masquerade/commit/1a3e7af7ff3988492b3d5d822b4bd48f5b4cc029))
* **list:** add split/join list parser ([6c095dc](https://github.com/howard86/masquerade/commit/6c095dc3dac2bcacdbe5e6f7b7a24d4d5c9e1710))
* make activity history actionable ([11e7b43](https://github.com/howard86/masquerade/commit/11e7b43a49a51bb3721d4ca6e944062c6729a76c))
* make activity history actionable ([99c05c7](https://github.com/howard86/masquerade/commit/99c05c734b5393f4a20eb66025689f2c8345ebcc))
* Math expression evaluator tool ([2fd2cc2](https://github.com/howard86/masquerade/commit/2fd2cc2406cce2f9699e8f80a10cc90fc1f2fd0f))
* Math visible tape unlock + canvas width-gate helper (Direction B phase 7) ([a266f45](https://github.com/howard86/masquerade/commit/a266f4530597bdf0ffbcefaae2dba17f629b63f2))
* **mobile:** improve iPhone usability and accessibility ([ce5656e](https://github.com/howard86/masquerade/commit/ce5656e1efe7e2224c68fa8bbe63ff81a46880ef))
* **mobile:** make the Library scannable ([9bd026a](https://github.com/howard86/masquerade/commit/9bd026a89caa782798a2f4237475b68430ea6a5f))
* **mq:** hide ToolActionBar paste button when no handler is bound ([8823f7d](https://github.com/howard86/masquerade/commit/8823f7d58bac383f67ef5379e391760a2c3d3aa1))
* **mq:** InlineToolCard header morph + MqRecentsRow ([318183a](https://github.com/howard86/masquerade/commit/318183ae7c5a5ff153721c6ff4eab63fa472bc95))
* Number Base interactive bit-grid at canvas width (Direction B phase 7) ([88187d3](https://github.com/howard86/masquerade/commit/88187d3e32e95e71c184167adcba4f396b64058a))
* **number-base:** precise parse error messages ([3fcd3a4](https://github.com/howard86/masquerade/commit/3fcd3a4088fa8b24d754111332fabaedc2fc0e7e))
* **number-base:** precise parse error messages ([dc6e6f6](https://github.com/howard86/masquerade/commit/dc6e6f6cf0d06f25133776ba1ead9d143263620b))
* persist mobile tool drafts ([e1a2dbe](https://github.com/howard86/masquerade/commit/e1a2dbe053194d7aa86d1d8af1c13224e10f2940))
* persist mobile tool drafts ([19e3947](https://github.com/howard86/masquerade/commit/19e3947839c4832a8afb7938ee934e33dfc2ec70))
* pipe-drag pipeline — typed in-canvas drags (Direction B phase 4) ([5f66da6](https://github.com/howard86/masquerade/commit/5f66da6f15ed2bd9dc2b0e04108f8f06be3e217a))
* QR big preview + inline ECC/size controls (Direction B phase 7) ([35b7d88](https://github.com/howard86/masquerade/commit/35b7d88d4b49516d3c52e7a71e30d465fcb02e89))
* **qr:** add QR code reader and generator ([8b1e23f](https://github.com/howard86/masquerade/commit/8b1e23f4425e6a0e25fbe0ef2999115ac319f5a4))
* **qr:** add QR code reader and generator ([43850fa](https://github.com/howard86/masquerade/commit/43850fa1bf8bfb5b8032a6b6bf8c9362268ccc8a))
* remaining canvas link pairs — Number/Math, Timestamp/Math, List/Diff, Color (Direction B phase 6) ([89751ff](https://github.com/howard86/masquerade/commit/89751ffe9d6ee0ca3d0a4a23c5f7a9784aec6a3e))
* remember detection preferences ([acc4bd5](https://github.com/howard86/masquerade/commit/acc4bd56e3be1e928a73b7f43732b5a9baf34454))
* remember detection preferences ([2ff6473](https://github.com/howard86/masquerade/commit/2ff6473603c6d27ac3e393ffd9c5fbe0dbe8babe))
* **routing:** shared ToolDetailRoute wrapper ([e2c12ea](https://github.com/howard86/masquerade/commit/e2c12ea768491beeffbca3c029c7c9a955911e4b))
* **screens:** add Home, Search, History, Settings + tab scaffold ([e7cee56](https://github.com/howard86/masquerade/commit/e7cee568632f53eafca7572b72b5a65477cac144))
* **screens:** add utility catalog and 6 detail screens ([d19a3df](https://github.com/howard86/masquerade/commit/d19a3dfae9755e7ef9d5c649a5ac3f237adacc47))
* **search:** empty state on no matches + clearance token ([daf8ebc](https://github.com/howard86/masquerade/commit/daf8ebc5e3a561ab8ebdd17bb6980087ab723eb2))
* **search:** inline tool cards replace per-result push navigation ([cc397da](https://github.com/howard86/masquerade/commit/cc397da0c9bfd0492ecf5992f2269fbaef67d2d3))
* **splash:** Dart-side splash crossfade + MqMonogram/MqSplashScreen ([63b0923](https://github.com/howard86/masquerade/commit/63b09231df4c0a8c69c694a1b86e4e568385539d))
* **state:** add theme, history, and favorites controllers ([0df82e8](https://github.com/howard86/masquerade/commit/0df82e850ff6cca440287b7c0f3c2fb64ab039a1))
* **theme:** add Magic Box design tokens (colors, typography, metrics) ([7515221](https://github.com/howard86/masquerade/commit/7515221d0122da2427c3d71044e0917bc6cf8059))
* **theme:** add MqLayout.tabBarClearance + MqColors.onTint ([2749992](https://github.com/howard86/masquerade/commit/2749992df109ccb6f74945abb38035490ab48090))
* **theme:** bundle IBM Plex fonts and flutter_lucide dep ([65726bb](https://github.com/howard86/masquerade/commit/65726bbc269a0239a3127b32305c9cacd9112d71))
* **theme:** density tokens, controller, and MqTokens wiring ([5d0612e](https://github.com/howard86/masquerade/commit/5d0612ead280571131c73f67bba1c8746112a268))
* **theme:** editorial design system foundation ([7b9dfd8](https://github.com/howard86/masquerade/commit/7b9dfd87b6926e82d60d3c9d277bfdac9ab8851e))
* **theme:** editorial palette and Plex typography with WCAG extensions ([abff078](https://github.com/howard86/masquerade/commit/abff0780f4ab46313e2eb0ec89657ee5e04f62da))
* Timestamp UTC/Local toggle + Now/Start-of-day keys at canvas width (Direction B phase 7) ([52930c1](https://github.com/howard86/masquerade/commit/52930c153fe92227595408e9abff64a22a569d2d))
* **timestamp:** expand formats and add keyword picker UI ([7dfe4ab](https://github.com/howard86/masquerade/commit/7dfe4ab068ef4ec5fa33d89682e231bf67605ca0))
* **timestamp:** expand formats and add keyword picker UI ([ad7b25d](https://github.com/howard86/masquerade/commit/ad7b25d38a61c9ed9eed89200b2645982364d12a))
* **tools:** add OpenInFooter for cross-tool output piping ([5369a27](https://github.com/howard86/masquerade/commit/5369a27ffeddd685b7e185f80a4726dd048f4408))
* **ui:** add clear affordance to MqSearchBar ([d0d0128](https://github.com/howard86/masquerade/commit/d0d0128624826bff9a8a59170a43c338621e1572))
* **ui:** add clear affordance to MqSearchBar ([67f9627](https://github.com/howard86/masquerade/commit/67f9627fe6eaa5484c6b0187f13d0a55b2f0253c))
* **ui:** add InlineToolCard, HistoryRecorder, SeedSource scaffolding ([dfbbb3e](https://github.com/howard86/masquerade/commit/dfbbb3ec71e3abc1c56478fa0421edac1104762a))
* **url:** add and remove query pairs in the editable table ([c8049ad](https://github.com/howard86/masquerade/commit/c8049ad6fb23dd9ddb819dcb9102f2a1d7570c74))
* **url:** add and remove query pairs in the editable table ([4f2d54d](https://github.com/howard86/masquerade/commit/4f2d54d8e6d1f18853257bec71e0d654506467a3))
* **utils:** add number base, JSON, color, and bps parsers ([6f82913](https://github.com/howard86/masquerade/commit/6f829138c4b7ff9362178b3594d4a477d6842684))
* **web:** add desktop shell, sidebar, and in-pane tool view ([3dcb58e](https://github.com/howard86/masquerade/commit/3dcb58e2a903f280bc18b983bbf02cca78104134))
* **web:** add view-mode state and shell-layout resolver ([3f0bcf3](https://github.com/howard86/masquerade/commit/3f0bcf3c333b2fafa48b12090667819f9ef6c82b))
* **web:** brand icons, PWA splash, manifest + theme-color meta ([7f2d29e](https://github.com/howard86/masquerade/commit/7f2d29ed17184f5441d983be557b4f3870af3002))
* **web:** desktop view on web with a desktop↔mobile toggle ([31719b7](https://github.com/howard86/masquerade/commit/31719b7de2757611768c86a3eed6f25c2bb2b3a0))
* **web:** move the desktop toggle into the iPhone frame ([ef64908](https://github.com/howard86/masquerade/commit/ef64908ff3498d1b2096ca6028e5eb8f54e452a9))
* **web:** regenerate favicon + PWA icons + splash for hammer+quill ([c3c10bc](https://github.com/howard86/masquerade/commit/c3c10bc4a070e2025b4cbb4f206de69e16a9ef15))
* **web:** render desktop view on wide web with a layout toggle ([fe17c54](https://github.com/howard86/masquerade/commit/fe17c54836668426302a9081aedbec826dbc1f28))
* **web:** v1.7.0 launch SEO metadata + PWA manifest ([d534f3d](https://github.com/howard86/masquerade/commit/d534f3d4e8d93b21ab7846d51c9005f7dc8bb36a))
* **widgets:** add Magic Box component primitives ([d0b99f5](https://github.com/howard86/masquerade/commit/d0b99f5b5f9919622c693d3ca2738a34a66387a0))
* **widgets:** add masthead, rule, reading block, wordmark, monogram ([ce73989](https://github.com/howard86/masquerade/commit/ce739891293f486f9b004a777fd2418cb746f94b))
* **widgets:** refresh mq components with editorial tokens ([6b1f398](https://github.com/howard86/masquerade/commit/6b1f3982b0708deda1f64d1b4a10411527e508b8))
* **widgets:** remap MqIcons to Lucide ([e89db27](https://github.com/howard86/masquerade/commit/e89db274631637f2eaadc5a77a840746ef9ce8cf))
* wire flagship Base64↔JSON live link end-to-end (ADR 0001) ([a593f77](https://github.com/howard86/masquerade/commit/a593f775d5370c960802aedca8fbc4e89bd9b2da))


### Bug Fixes

* **a11y:** expose mobile controls once ([36a555e](https://github.com/howard86/masquerade/commit/36a555ed0d77f69172914ae470d44ff929fd4a4a))
* **a11y:** keep layouts within bounds at large Dynamic Type ([e875539](https://github.com/howard86/masquerade/commit/e875539ef5c00eb411e6c10b8040d9fdd8321e07))
* **a11y:** keep the layouts sheet row hit area at full height ([79ef125](https://github.com/howard86/masquerade/commit/79ef1253327b0f703ac9f311e42c367a27073294))
* **a11y:** mask Copy-all toast preview for sensitive payloads ([5f85b1a](https://github.com/howard86/masquerade/commit/5f85b1aa0bf53ac073918933cf1777000fb17a04))
* **a11y:** mask Copy-all toast preview for sensitive payloads ([8dd4305](https://github.com/howard86/masquerade/commit/8dd4305f40f302d378ee924ee3892a19d670a57b))
* avoid warning for ordinary spaces ([5441efd](https://github.com/howard86/masquerade/commit/5441efdd48a0a327d52963192d253733471f19d1))
* block sensitive values from history ([fd4fe63](https://github.com/howard86/masquerade/commit/fd4fe635a213b1c184fc6a4e4066915a2c76e626))
* block sensitive values from history ([d1a7569](https://github.com/howard86/masquerade/commit/d1a75698196f384d94ae41f683b7dd5869f42985))
* **ci:** auto-merge the release sync PR ([36ee878](https://github.com/howard86/masquerade/commit/36ee878e16f5e1bffc3e70ac12264c43f2d86a6e))
* **ci:** auto-merge the release sync PR ([914c31b](https://github.com/howard86/masquerade/commit/914c31bbd7c09bd2422494fb9002c7bd4ea03970))
* **ci:** bump commitizen to 4.13.9 for action 0.27.1 compatibility ([cb54f45](https://github.com/howard86/masquerade/commit/cb54f4587b566f7a5a4ec553f1b5d52a0430dba9))
* **ci:** repair release automation ([21e5698](https://github.com/howard86/masquerade/commit/21e56982139fbed0cf78a6154d6f66afd5264bb0))
* **ci:** rerun checks after release retarget ([ff631ec](https://github.com/howard86/masquerade/commit/ff631ec2f75c8fe367979499bc31f36087218c07))
* **ci:** rerun checks after release retarget ([fc43def](https://github.com/howard86/masquerade/commit/fc43def56f1510f2e90d9bd9a77e311f1aac9880))
* **ci:** sign share extension separately ([b32cb39](https://github.com/howard86/masquerade/commit/b32cb39aed953367c446faac575316de53ac7793))
* **ci:** sync releases through pull requests ([c4e974a](https://github.com/howard86/masquerade/commit/c4e974a2533fe9ef69e06e73476e57b2bcb10e20))
* **color:** reject out-of-range RGB/HSL channels instead of silently clamping ([810fce9](https://github.com/howard86/masquerade/commit/810fce9cb69da5a13f758fa0bb2e749346fe3f78))
* **color:** reject out-of-range RGB/HSL channels instead of silently clamping ([00c203b](https://github.com/howard86/masquerade/commit/00c203bc71dc0e96f7e8b06806f95f9c88b34556))
* correct Dependabot metadata ([b01e02c](https://github.com/howard86/masquerade/commit/b01e02c7d1319faaadea62c6a8dd745fbac643d9))
* **deps:** pin flutter_native_splash to ^2.4.7 for SDK compatibility ([e5d93d6](https://github.com/howard86/masquerade/commit/e5d93d657cff277a36cf2bbded9ebd075a9903a7))
* **deps:** pin flutter_native_splash to ^2.4.7 for SDK compatibility ([dc896e9](https://github.com/howard86/masquerade/commit/dc896e9566c6ac17b7ecd531702c425c65236e3f))
* **desktop:** keep dragged windows under cursor ([ba50f03](https://github.com/howard86/masquerade/commit/ba50f039a62350b14c3403536c003e45d78e0efc))
* **desktop:** keep launchers visible ([45a1bf5](https://github.com/howard86/masquerade/commit/45a1bf52b656f4b1c5e5c5d06aad8e74c43af8a1))
* **detail:** ellipsize long tool names in the nav bar ([6980c79](https://github.com/howard86/masquerade/commit/6980c791743967c449a3b3102d47751e9f6a3741))
* detect quoted one-column CSV ([29d7255](https://github.com/howard86/masquerade/commit/29d725502790882471a281e6cd63a1077207b23d))
* **detect:** defer Math to List for bulleted/numbered input ([7521ccb](https://github.com/howard86/masquerade/commit/7521ccbe176623a76f8c18d344bbdb7e483606a0))
* drop iPad support (iPhone-only target), bump build to 1.25.2+3 ([b15d010](https://github.com/howard86/masquerade/commit/b15d010f5f233c5381512108d4245ae8ae8e7357))
* drop iPad support, target iPhone only ([45b74eb](https://github.com/howard86/masquerade/commit/45b74eb1a98f179cde4947c4d1daeb85679e7926))
* **home:** early-return _onHeroChange when unmounted ([5ed7d06](https://github.com/howard86/masquerade/commit/5ed7d068ceeff3d17a6b2590fdf9e1facbe58ce8))
* **icons:** map flash + flashFill to distinct Lucide glyphs ([c797e7b](https://github.com/howard86/masquerade/commit/c797e7b371dc23a57d09d43b88b2e22117ed3c1f))
* isolate regex matching with hard timeout ([c20b17c](https://github.com/howard86/masquerade/commit/c20b17c954d3a1f39ee7e3ee93eb95ad336903c3))
* **lint:** adopt Dart 3 wildcard params and null-aware elements ([8ead1a6](https://github.com/howard86/masquerade/commit/8ead1a63eaf873f5717f28ecec372bdac94156d4))
* **list:** thread actionBar through List tool after Magic Box merge ([89bde65](https://github.com/howard86/masquerade/commit/89bde656d60dc42eb4126ddbe9fdbf23f673ebf4))
* **mobile:** inset scanner guidance above tab bar ([9de5843](https://github.com/howard86/masquerade/commit/9de58431664f6c3eb4c3440658f2c7c6a17e0ceb))
* **mobile:** keep pushed routes above tab bar ([0655853](https://github.com/howard86/masquerade/commit/065585374ff16a4a041f0d39a753a74f3a65cd08))
* **mobile:** simplify the empty Workbench ([8064136](https://github.com/howard86/masquerade/commit/80641360c78062a7b5ea1830cf6635408cc5856b))
* **mobile:** unify page hierarchy and action labels ([0d82841](https://github.com/howard86/masquerade/commit/0d82841d6704e6992ce05b41e7da5c1b25e7a352))
* **mq:** add MqChip selected prop so action chips stop announcing "selected" ([b61f9f9](https://github.com/howard86/masquerade/commit/b61f9f970347828d324857ac90ae8c48055f737b))
* **mq:** add MqChip selected prop so action chips stop announcing "selected" ([30aa16a](https://github.com/howard86/masquerade/commit/30aa16a32af149015dddd601561479791ec2d2cc))
* **nav:** add 10px top padding to tab bar icons ([769fa87](https://github.com/howard86/masquerade/commit/769fa87d9013ea516d939105d965ae3b88c4f759))
* **nav:** give tab bar vertical breathing room ([4a87caa](https://github.com/howard86/masquerade/commit/4a87caae4aeb61df2fe0c3ca4ef855a6216e0574))
* preserve shared input during handoff removal ([8cd6a1f](https://github.com/howard86/masquerade/commit/8cd6a1f7dfb668d1f76035975f5ad984942b811c))
* prevent MqStatus label overflow on long messages ([831aabf](https://github.com/howard86/masquerade/commit/831aabf985343dd692b4c2f4e789fae523c59410))
* prevent MqStatus label overflow on long messages ([e4dae4c](https://github.com/howard86/masquerade/commit/e4dae4c039ea013977fad7d742d42ab1bb72996f))
* protect sensitive data surfaces ([f0b648c](https://github.com/howard86/masquerade/commit/f0b648cf973fd7915532c61e9b328897d393d671))
* protect sensitive data surfaces ([53be15a](https://github.com/howard86/masquerade/commit/53be15ad436771821457b2fa06f4bd966b6d5582))
* **qr:** dispose ui.Image after PNG encode to free native memory ([152011d](https://github.com/howard86/masquerade/commit/152011d89175651a9ff2838048814f5223847349))
* **qr:** share works on web by dropping dart:io File temp-write ([b6b803a](https://github.com/howard86/masquerade/commit/b6b803a99e7443ddb85b05d1bea88ec07e397505))
* reject lossy HTTP request inputs ([05c52d3](https://github.com/howard86/masquerade/commit/05c52d342760a7fc0ff65cf87f0a9b36d65ea8f4))
* set iOS bundle identifier to dev.howardism.Masquerade ([b23ced6](https://github.com/howard86/masquerade/commit/b23ced6a059792bffc05e19ffd588f3761f8c22a))
* **settings:** show live pubspec version + use clearance token ([b235762](https://github.com/howard86/masquerade/commit/b235762828326beeb3440a4739a10e1f960b9adb))
* show incompatible saved workflow steps ([b3d9fe6](https://github.com/howard86/masquerade/commit/b3d9fe6576dc64b8c70a15ba895b2096e44447f1))
* text fits on screen at all sizes (Dynamic Type + long content) ([1296fbd](https://github.com/howard86/masquerade/commit/1296fbd0e8985691db03c6e7bd50171000307191))
* **timestamp:** guard large-integer precision on web (BigInt) ([33218df](https://github.com/howard86/masquerade/commit/33218df1e1d4cc7071bb20a1cf64eef6ea990980))
* **timestamp:** guard large-integer precision on web (BigInt) ([45d72cd](https://github.com/howard86/masquerade/commit/45d72cd9dbd7c7c96aeee866c98e4c7301ac7ea0))
* **timestamp:** surface ambiguity badge in seconds/ms overlap range ([fb80a1c](https://github.com/howard86/masquerade/commit/fb80a1c9735e6fc537de72c4a694202c455cfc35))
* **tools:** shorten input placeholders to fit the field ([762c013](https://github.com/howard86/masquerade/commit/762c013f97eb5642dea4732a15357834fe7f96de))
* **url:** carry edited query pairs through Swap ([ace0b98](https://github.com/howard86/masquerade/commit/ace0b98abe11dc682243043445823457c6874f53))
* **url:** carry edited query pairs through Swap ([527ba6c](https://github.com/howard86/masquerade/commit/527ba6cbf070e12307050fa85a6e30c71486627a))
* **url:** carry edited query pairs through the cross-tool Link ([3eb81ce](https://github.com/howard86/masquerade/commit/3eb81ce6a7cdf465f279228c8c0396c2d6fd1e83))
* **url:** carry edited query pairs through the cross-tool Link ([20f0874](https://github.com/howard86/masquerade/commit/20f087402c9c5d0135e440d2998e545f4d2aa275))
* **url:** only splice the rebuilt query when the table was edited ([0264626](https://github.com/howard86/masquerade/commit/0264626cb88bd57861ef8982666722571a1fc813))
* **utils:** clamp text_truncate max and avoid splitting surrogate pairs ([8b16b9d](https://github.com/howard86/masquerade/commit/8b16b9d58d797cc5832f335728cf93cf87be15a4))
* **utils:** clamp text_truncate max and avoid splitting surrogate pairs ([f63966f](https://github.com/howard86/masquerade/commit/f63966f26930a2255667188c1c1cc54aefcad3a1))


### Performance Improvements

* **bytes:** virtualize hexdump row list ([53f75d1](https://github.com/howard86/masquerade/commit/53f75d183be247a33c7e4c18fd5a6d79e6016bb3))
* **bytes:** virtualize hexdump row list ([48b2bda](https://github.com/howard86/masquerade/commit/48b2bda80bd758879790ab2d27278ee741521f0c))
* **ci:** parallelise CI and drop duplicate work ([5632c77](https://github.com/howard86/masquerade/commit/5632c7716723ad0059f1b8a61d04ccfb575dc74e))
* **ci:** parallelise jobs and drop duplicate pub cache ([c79981c](https://github.com/howard86/masquerade/commit/c79981c47f378f48b08986900b9570f7d71fe556))
* **ci:** shard the test suite across three runners ([7ed67aa](https://github.com/howard86/masquerade/commit/7ed67aa4bc8afe7f7ec0bbe4499165fa2f70da6c))
* **ci:** shard the test suite across three runners ([8fe8d44](https://github.com/howard86/masquerade/commit/8fe8d440d70fce005230e1dfbeb957617d77febe))
* **ci:** skip duplicate Xcode build before fastlane archive ([5a51451](https://github.com/howard86/masquerade/commit/5a51451da7e9ad464603b01006e1d13a3a907d13))
* **theme:** cache Listenable.merge and drop MqDensityScope ([798e454](https://github.com/howard86/masquerade/commit/798e45490ebaa2ed38f8d8b9780fbb51a81e88f4))

## [1.27.0](https://github.com/howard86/masquerade/compare/v1.26.1...v1.27.0) (2026-07-29)


### Features

* **a11y:** extend Copy-all to Hash, JWT, and bps tool bodies ([23037b6](https://github.com/howard86/masquerade/commit/23037b622083298b125a0e055a41f06df65d3ba9))
* **a11y:** extend Copy-all to Hash, JWT, and bps tool bodies ([4ba3610](https://github.com/howard86/masquerade/commit/4ba36108105f6b399d4f8ad0e32014dff5dadc70))
* **a11y:** Semantics(button) for Timestamp picker rows ([1659d03](https://github.com/howard86/masquerade/commit/1659d0332393a0313e86030af084ef8d764006b5))
* **a11y:** Semantics(button) for Timestamp picker rows ([0cfd8ec](https://github.com/howard86/masquerade/commit/0cfd8eca962f226b6f9ef1fcd09164dae209f77b))
* add Copy-all action for multi-output tools (Number Base, Color) ([5e54dc4](https://github.com/howard86/masquerade/commit/5e54dc493bc17e213dcc9d9cac1f9d266abd25e3))
* Copy-all action for multi-output tools (Number Base, Color) ([075de98](https://github.com/howard86/masquerade/commit/075de9851f0e1e596ee60c29b167d820b655aa8d))


### Bug Fixes

* **ci:** auto-merge the release sync PR ([36ee878](https://github.com/howard86/masquerade/commit/36ee878e16f5e1bffc3e70ac12264c43f2d86a6e))
* **ci:** auto-merge the release sync PR ([914c31b](https://github.com/howard86/masquerade/commit/914c31bbd7c09bd2422494fb9002c7bd4ea03970))
* **utils:** clamp text_truncate max and avoid splitting surrogate pairs ([8b16b9d](https://github.com/howard86/masquerade/commit/8b16b9d58d797cc5832f335728cf93cf87be15a4))
* **utils:** clamp text_truncate max and avoid splitting surrogate pairs ([f63966f](https://github.com/howard86/masquerade/commit/f63966f26930a2255667188c1c1cc54aefcad3a1))


### Performance Improvements

* **ci:** parallelise CI and drop duplicate work ([5632c77](https://github.com/howard86/masquerade/commit/5632c7716723ad0059f1b8a61d04ccfb575dc74e))
* **ci:** parallelise jobs and drop duplicate pub cache ([c79981c](https://github.com/howard86/masquerade/commit/c79981c47f378f48b08986900b9570f7d71fe556))
* **ci:** shard the test suite across three runners ([7ed67aa](https://github.com/howard86/masquerade/commit/7ed67aa4bc8afe7f7ec0bbe4499165fa2f70da6c))
* **ci:** shard the test suite across three runners ([8fe8d44](https://github.com/howard86/masquerade/commit/8fe8d440d70fce005230e1dfbeb957617d77febe))
* **ci:** skip duplicate Xcode build before fastlane archive ([5a51451](https://github.com/howard86/masquerade/commit/5a51451da7e9ad464603b01006e1d13a3a907d13))

## [1.26.1](https://github.com/howard86/masquerade/compare/v1.26.0...v1.26.1) (2026-07-26)


### Bug Fixes

* **ci:** repair release automation ([21e5698](https://github.com/howard86/masquerade/commit/21e56982139fbed0cf78a6154d6f66afd5264bb0))
* **ci:** rerun checks after release retarget ([ff631ec](https://github.com/howard86/masquerade/commit/ff631ec2f75c8fe367979499bc31f36087218c07))
* **ci:** rerun checks after release retarget ([fc43def](https://github.com/howard86/masquerade/commit/fc43def56f1510f2e90d9bd9a77e311f1aac9880))
* **ci:** sign share extension separately ([b32cb39](https://github.com/howard86/masquerade/commit/b32cb39aed953367c446faac575316de53ac7793))
* **ci:** sync releases through pull requests ([c4e974a](https://github.com/howard86/masquerade/commit/c4e974a2533fe9ef69e06e73476e57b2bcb10e20))

## [1.26.0](https://github.com/howard86/masquerade/compare/v1.25.2...v1.26.0) (2026-07-26)


### Features

* **a11y:** add semantics labels + haptics to bare icon tap targets ([9b21a5a](https://github.com/howard86/masquerade/commit/9b21a5a7853e9e95fe46c760223399f27068aef6))
* **a11y:** announce diff collapse + bare tap targets to screen readers ([b78c280](https://github.com/howard86/masquerade/commit/b78c280a069d064994093e27ba444aa630e45351))
* **a11y:** announce MqStatus errors via a Semantics live region ([002b993](https://github.com/howard86/masquerade/commit/002b9937f326fdd592315fe57f1b902e7d9088ec))
* **a11y:** announce MqStatus errors via a Semantics live region ([a139f7f](https://github.com/howard86/masquerade/commit/a139f7f42224695905e61cf7e5f49d58e752c277))
* **a11y:** button Semantics for the shared MqChip ([cbf4f72](https://github.com/howard86/masquerade/commit/cbf4f72527862ec90ba615eadcf45424e1b95ab5))
* **a11y:** button Semantics for the shared MqChip ([9e98fc7](https://github.com/howard86/masquerade/commit/9e98fc74bf361d4d3f3fb8bea34bd701ea305497))
* **a11y:** keyboard navigation for the desktop icon grid ([dbffc29](https://github.com/howard86/masquerade/commit/dbffc2913896b65ba0a95dce6bbd74caff6cfd7d))
* **a11y:** keyboard navigation for the desktop icon grid ([ebe7dbe](https://github.com/howard86/masquerade/commit/ebe7dbe9bdbd7a5eb58ca49f2310a22633acb9e1))
* **a11y:** Semantics for diff collapse control + remaining bare tap targets ([7b88edd](https://github.com/howard86/masquerade/commit/7b88edd3d48fded4548ab8df085645643ec35188))
* **a11y:** Semantics labels + haptics on bare icon tap targets ([b1656a5](https://github.com/howard86/masquerade/commit/b1656a5a75b99f2768746fcc29f730e521ff2c4a))
* **a11y:** Semantics labels for desktop dock tiles ([a8ce1f4](https://github.com/howard86/masquerade/commit/a8ce1f435e76cc4e4691823239a591110e7dda94))
* **a11y:** Semantics labels for desktop dock tiles ([2154c24](https://github.com/howard86/masquerade/commit/2154c2498706ca11a7456ea41e6d58c03fd3ce24))
* add artifact detection models ([6c80e22](https://github.com/howard86/masquerade/commit/6c80e22b9ec0ec557500a485935c66c181623a42))
* add artifact detection models ([f824f85](https://github.com/howard86/masquerade/commit/f824f854ecaabb333689d9b615e5f10e4b901dbd))
* add case converter ([1c33afb](https://github.com/howard86/masquerade/commit/1c33afb7b0ced688be354eab8e96b76b997d82c2))
* add case converter ([ad20cd1](https://github.com/howard86/masquerade/commit/ad20cd16f6c7cb8408d85f73fb17332c3000852b))
* add categorized library favorites ([a98eb14](https://github.com/howard86/masquerade/commit/a98eb14d75df616616f20ba76c00131efaec2326))
* add categorized library favorites ([9a8c926](https://github.com/howard86/masquerade/commit/9a8c926117247a92b755f52e1b3c8bf49b334365))
* add Copy-all action to Timestamp and IP tools ([6a96d6b](https://github.com/howard86/masquerade/commit/6a96d6b4fdc16d65260fe73454ffebb96e3a4273))
* add CSV and TSV converter ([8f9b691](https://github.com/howard86/masquerade/commit/8f9b69134929382f98c1ea98f55690a9f490048a))
* add CSV and TSV converter ([58e5d56](https://github.com/howard86/masquerade/commit/58e5d564d508cd9917680c466dd5f0070e7a5862))
* add environment config inspector ([df02e34](https://github.com/howard86/masquerade/commit/df02e342fad136f0731c1b76f40fc14d171bac04))
* add environment config inspector ([7bf151d](https://github.com/howard86/masquerade/commit/7bf151de62a420dc1113afc1f5bb6706d26329ce))
* add focused iOS app intents ([aa96175](https://github.com/howard86/masquerade/commit/aa961751a22844025a77a6382e2da2e6ee6d66e2))
* add focused iOS app intents ([4456704](https://github.com/howard86/masquerade/commit/44567045ee3279d5116b223fecbeab94696ff080))
* add HTTP request inspector ([5442d52](https://github.com/howard86/masquerade/commit/5442d5269010cb2c74c1cefb17a241d5908d2586))
* add HTTP request inspector ([c125b30](https://github.com/howard86/masquerade/commit/c125b30ff2330450c205b7ca3cc38d0b4ba882f6))
* add iOS share inbox extension ([9b24475](https://github.com/howard86/masquerade/commit/9b244758a67901b0951cca662a81b1a9a7fff7d8))
* add iOS share inbox extension ([fdbf61a](https://github.com/howard86/masquerade/commit/fdbf61a92920a2e0c1b67750361588edbfe84288))
* add log and stack inspector ([85ae5b7](https://github.com/howard86/masquerade/commit/85ae5b7dc9993af286fd62369512e63922b374c4))
* add log and stack inspector ([ec16e50](https://github.com/howard86/masquerade/commit/ec16e506e054101607a85b67f82c55dd08bdc049))
* add Markdown preview tool ([b4bf020](https://github.com/howard86/masquerade/commit/b4bf0207bb5ef1f6710a8ae91a0d2d1496ee8cb5))
* add Markdown preview tool ([2450455](https://github.com/howard86/masquerade/commit/2450455d061186565382cc7c8a5a917dffe13da9))
* add mobile session step actions ([98e7566](https://github.com/howard86/masquerade/commit/98e75666a8c2e29fffe557b423e112bd24c9ace1))
* add mobile session step actions ([05106e3](https://github.com/howard86/masquerade/commit/05106e3b91eed3bd09b900ec012724afaaab60b0))
* add mobile workbench library activity shell ([6fcf1e8](https://github.com/howard86/masquerade/commit/6fcf1e8096b488554e12b682afc25353efe2a46c))
* add mobile workbench library activity shell ([0a46af2](https://github.com/howard86/masquerade/commit/0a46af272e0ca00e8f5b165f052763a46b8c6f61))
* add mobile workflow sessions ([b757750](https://github.com/howard86/masquerade/commit/b7577503c595481ff552d1729b59ee768b893601))
* add mobile workflow sessions ([390bd98](https://github.com/howard86/masquerade/commit/390bd98f96da11abfad2237e7356e5296aa79077))
* add persisted work session models ([d073a52](https://github.com/howard86/masquerade/commit/d073a523a8eb1adb73a6098300373ffbbff0a089))
* add persisted work session models ([93e4f7f](https://github.com/howard86/masquerade/commit/93e4f7fb19a425a490bc36ca1f45f7c3ec662095))
* add privacy and acknowledgements screens ([1c531d5](https://github.com/howard86/masquerade/commit/1c531d58c5a497ebde6d4accfebdac4d6dfe5798))
* add privacy and acknowledgements screens ([d037412](https://github.com/howard86/masquerade/commit/d037412299561ff3110c7209158f87f3dd8046f3))
* add ranked artifact detection ([c46033c](https://github.com/howard86/masquerade/commit/c46033cef71b991cd3894f0285dae9bc62ecd7dc))
* add ranked artifact detection ([a423d0b](https://github.com/howard86/masquerade/commit/a423d0bfbadbf5d6f888cd5dff382553edbb1197))
* add recursive artifact inspector ([b1f6ff6](https://github.com/howard86/masquerade/commit/b1f6ff679ae14445356fde4195feb7d4b73335d1))
* add recursive artifact inspector ([1d491ed](https://github.com/howard86/masquerade/commit/1d491edb8f50f8eb36266c6859e66998c773d4b0))
* add regex tester ([60329ed](https://github.com/howard86/masquerade/commit/60329edf762c8524a2f6ebb177c3554e7c9c047f))
* add regex tester ([e28630a](https://github.com/howard86/masquerade/commit/e28630a40394de280c90ee3d929123f5e0e7ac69))
* add reusable saved workflows ([d0ef43d](https://github.com/howard86/masquerade/commit/d0ef43d49e6c2453483154b7c4183369fcbbb989))
* add reusable saved workflows ([096fc18](https://github.com/howard86/masquerade/commit/096fc185396f360d965d9126ae560ad15b732641))
* add safe Spotlight shortcut discovery ([cbd5399](https://github.com/howard86/masquerade/commit/cbd5399a8191c9629676e04f55244852acb6a333))
* add safe Spotlight shortcut discovery ([d064305](https://github.com/howard86/masquerade/commit/d064305d82d70a88d6ed015ca6f428f173a9aece))
* add typed catalog routing metadata ([211aa97](https://github.com/howard86/masquerade/commit/211aa9763ecfe11508468766d458971e56bd30e8))
* add typed catalog routing metadata ([27cb7bd](https://github.com/howard86/masquerade/commit/27cb7bdb5d5f96d6f8f828010be2b101263441fd))
* add Unicode string inspector ([7e7822d](https://github.com/howard86/masquerade/commit/7e7822d640278fc86e995d82a4c0e578d325a3a0))
* add Unicode string inspector ([3dfa978](https://github.com/howard86/masquerade/commit/3dfa978a9699dac1bd942cc6eb353e02c45d8608))
* add URL encode/decode + query-string tool ([d938fae](https://github.com/howard86/masquerade/commit/d938fae53e37a14084d2e34f1318d248c99baf49))
* add URL encode/decode + query-string tool ([61feb38](https://github.com/howard86/masquerade/commit/61feb38dd4b611735ce5f860e166527c0e43a041))
* add workbench capture states ([1c1c34c](https://github.com/howard86/masquerade/commit/1c1c34c4b175af3f5e3bfd6fbf02e4aedb3b58a0))
* add workbench capture states ([b2ce5e5](https://github.com/howard86/masquerade/commit/b2ce5e50150fd4d5c9204f6a1f3d5401756ee6ae))
* add X.509 certificate inspector ([a188f0c](https://github.com/howard86/masquerade/commit/a188f0c8e95a2a5ccd3a3b732ce1b68cb58cd6f8))
* add X.509 certificate inspector ([4d8ca69](https://github.com/howard86/masquerade/commit/4d8ca693b9c1272e7e378a3ab260977819b14e0d))
* arrow-key 2D traversal for the desktop icon grid ([d3aa480](https://github.com/howard86/masquerade/commit/d3aa48028a9c1f018dfb43016693116d69673414))
* arrow-key 2D traversal for the desktop icon grid ([fac3aee](https://github.com/howard86/masquerade/commit/fac3aee6d9868aa89fb5dd51410c36c104378ad8))
* bring the desktop OS to native macOS ([f7d3507](https://github.com/howard86/masquerade/commit/f7d350732333b17925ee1ff7c30cc291f4eb5a27))
* Copy-all action for Timestamp and IP tools ([fe6f29c](https://github.com/howard86/masquerade/commit/fe6f29c313d72288d12f1b653f3002986345c5fe))
* **desktop:** empty-state for Spotlight command palette ([546eba6](https://github.com/howard86/masquerade/commit/546eba6539431056a30777b28167e3870a920c25))
* **desktop:** empty-state for Spotlight command palette ([d38d084](https://github.com/howard86/masquerade/commit/d38d08446cc02028f15843e5b4326787f01c4964))
* **desktop:** enable native macOS shell ([fd51934](https://github.com/howard86/masquerade/commit/fd51934c9b4a8bba6f2a40053c5b14172cc8d2d5))
* editable two-way query table for the URL tool ([a6c1a15](https://github.com/howard86/masquerade/commit/a6c1a155448f4ca678088f92d2fc8e9ae35cbb90))
* editable two-way query table for the URL tool ([031bad3](https://github.com/howard86/masquerade/commit/031bad32608560ddf243c94462f3cd38bf45db2c))
* **generator:** guarantee one char per enabled class + show entropy ([f8f36fd](https://github.com/howard86/masquerade/commit/f8f36fd2f38acfce70d3954c58616325e006a233))
* **generator:** guarantee one char per enabled class + show entropy ([21cf7a1](https://github.com/howard86/masquerade/commit/21cf7a19f6c81b2d1bf0cd174e427c8f2c49a5e1))
* grow AnimatedCopyIcon hit target to 44x44 ([512d9ab](https://github.com/howard86/masquerade/commit/512d9ab6904e7d1d093304a7ead780be4a5c54f8))
* grow AnimatedCopyIcon hit target to 44x44 ([45a4a59](https://github.com/howard86/masquerade/commit/45a4a598ba70cbb07b34fb9fce03ef369eccaf9d))
* grow MqMonoCell copy hit target to 44x44 (HIG) ([af0afb1](https://github.com/howard86/masquerade/commit/af0afb1607c8a7aa4903d021c50aab937f149621))
* grow MqMonoCell copy hit target to 44x44 (HIG) ([6113c16](https://github.com/howard86/masquerade/commit/6113c16a676e8b4727f07ca955b7f88705ce5172))
* import external Workbench inputs ([8e9aa12](https://github.com/howard86/masquerade/commit/8e9aa12d0e1c5bc2b5cc6f295f046f41d6ca523a))
* import external Workbench inputs ([1bc229b](https://github.com/howard86/masquerade/commit/1bc229b166eb508e3ae0b3349f9a1f02cc1f089b))
* make activity history actionable ([11e7b43](https://github.com/howard86/masquerade/commit/11e7b43a49a51bb3721d4ca6e944062c6729a76c))
* make activity history actionable ([99c05c7](https://github.com/howard86/masquerade/commit/99c05c734b5393f4a20eb66025689f2c8345ebcc))
* **number-base:** precise parse error messages ([3fcd3a4](https://github.com/howard86/masquerade/commit/3fcd3a4088fa8b24d754111332fabaedc2fc0e7e))
* **number-base:** precise parse error messages ([dc6e6f6](https://github.com/howard86/masquerade/commit/dc6e6f6cf0d06f25133776ba1ead9d143263620b))
* persist mobile tool drafts ([e1a2dbe](https://github.com/howard86/masquerade/commit/e1a2dbe053194d7aa86d1d8af1c13224e10f2940))
* persist mobile tool drafts ([19e3947](https://github.com/howard86/masquerade/commit/19e3947839c4832a8afb7938ee934e33dfc2ec70))
* remember detection preferences ([acc4bd5](https://github.com/howard86/masquerade/commit/acc4bd56e3be1e928a73b7f43732b5a9baf34454))
* remember detection preferences ([2ff6473](https://github.com/howard86/masquerade/commit/2ff6473603c6d27ac3e393ffd9c5fbe0dbe8babe))


### Bug Fixes

* avoid warning for ordinary spaces ([5441efd](https://github.com/howard86/masquerade/commit/5441efdd48a0a327d52963192d253733471f19d1))
* block sensitive values from history ([fd4fe63](https://github.com/howard86/masquerade/commit/fd4fe635a213b1c184fc6a4e4066915a2c76e626))
* block sensitive values from history ([d1a7569](https://github.com/howard86/masquerade/commit/d1a75698196f384d94ae41f683b7dd5869f42985))
* **color:** reject out-of-range RGB/HSL channels instead of silently clamping ([810fce9](https://github.com/howard86/masquerade/commit/810fce9cb69da5a13f758fa0bb2e749346fe3f78))
* **color:** reject out-of-range RGB/HSL channels instead of silently clamping ([00c203b](https://github.com/howard86/masquerade/commit/00c203bc71dc0e96f7e8b06806f95f9c88b34556))
* correct Dependabot metadata ([b01e02c](https://github.com/howard86/masquerade/commit/b01e02c7d1319faaadea62c6a8dd745fbac643d9))
* **desktop:** keep dragged windows under cursor ([ba50f03](https://github.com/howard86/masquerade/commit/ba50f039a62350b14c3403536c003e45d78e0efc))
* **desktop:** keep launchers visible ([45a1bf5](https://github.com/howard86/masquerade/commit/45a1bf52b656f4b1c5e5c5d06aad8e74c43af8a1))
* detect quoted one-column CSV ([29d7255](https://github.com/howard86/masquerade/commit/29d725502790882471a281e6cd63a1077207b23d))
* drop iPad support (iPhone-only target), bump build to 1.25.2+3 ([b15d010](https://github.com/howard86/masquerade/commit/b15d010f5f233c5381512108d4245ae8ae8e7357))
* drop iPad support, target iPhone only ([45b74eb](https://github.com/howard86/masquerade/commit/45b74eb1a98f179cde4947c4d1daeb85679e7926))
* isolate regex matching with hard timeout ([c20b17c](https://github.com/howard86/masquerade/commit/c20b17c954d3a1f39ee7e3ee93eb95ad336903c3))
* **mq:** add MqChip selected prop so action chips stop announcing "selected" ([b61f9f9](https://github.com/howard86/masquerade/commit/b61f9f970347828d324857ac90ae8c48055f737b))
* **mq:** add MqChip selected prop so action chips stop announcing "selected" ([30aa16a](https://github.com/howard86/masquerade/commit/30aa16a32af149015dddd601561479791ec2d2cc))
* preserve shared input during handoff removal ([8cd6a1f](https://github.com/howard86/masquerade/commit/8cd6a1f7dfb668d1f76035975f5ad984942b811c))
* prevent MqStatus label overflow on long messages ([831aabf](https://github.com/howard86/masquerade/commit/831aabf985343dd692b4c2f4e789fae523c59410))
* prevent MqStatus label overflow on long messages ([e4dae4c](https://github.com/howard86/masquerade/commit/e4dae4c039ea013977fad7d742d42ab1bb72996f))
* protect sensitive data surfaces ([f0b648c](https://github.com/howard86/masquerade/commit/f0b648cf973fd7915532c61e9b328897d393d671))
* protect sensitive data surfaces ([53be15a](https://github.com/howard86/masquerade/commit/53be15ad436771821457b2fa06f4bd966b6d5582))
* reject lossy HTTP request inputs ([05c52d3](https://github.com/howard86/masquerade/commit/05c52d342760a7fc0ff65cf87f0a9b36d65ea8f4))
* set iOS bundle identifier to dev.howardism.Masquerade ([b23ced6](https://github.com/howard86/masquerade/commit/b23ced6a059792bffc05e19ffd588f3761f8c22a))
* show incompatible saved workflow steps ([b3d9fe6](https://github.com/howard86/masquerade/commit/b3d9fe6576dc64b8c70a15ba895b2096e44447f1))
* **timestamp:** guard large-integer precision on web (BigInt) ([33218df](https://github.com/howard86/masquerade/commit/33218df1e1d4cc7071bb20a1cf64eef6ea990980))
* **timestamp:** guard large-integer precision on web (BigInt) ([45d72cd](https://github.com/howard86/masquerade/commit/45d72cd9dbd7c7c96aeee866c98e4c7301ac7ea0))

## v1.25.1 (2026-06-12)

### Fix

- **deps**: pin flutter_native_splash to ^2.4.7 for SDK compatibility

### Refactor

- **tool_bodies**: introduce ToolBodyScaffold mixin and migrate all single-input bodies

## v1.25.0 (2026-05-29)

### Feat

- **desktop**: wire multi-directional resizing and draw L-shaped orthogonal link lines
- **desktop**: implement multi-directional resize handles, body tap to focus, and stateful traffic light hovers
- **desktop**: support grabbable Y-clamping and multi-directional edge resizing in CanvasController
- **desktop**: introduce tactile shortcuts HUD keycap modal
- **desktop**: structure right-aligned icon grid with spring bounce clicks
- **desktop**: add right-click context menu and animate minimized window snapping
- **desktop**: implement premium generative wallpaper styles
- **desktop**: add persistent wallpaper controller state management

## v1.24.0 (2026-05-24)

### Feat

- **desktop**: History & Settings as system windows
- **desktop**: window manager — traffic lights, z-order, min/max/snap, dock
- **desktop**: desktop icon grid + Spotlight palette
- **desktop**: replace sidebar with full-bleed macOS-style shell

## v1.23.0 (2026-05-23)

### Feat

- add Generator tool (password / token / UUID)
- add UUID / ULID parser tool

## v1.22.0 (2026-05-23)

### Feat

- add IP / CIDR parser tool

## v1.21.0 (2026-05-23)

### Feat

- add Hash tool (MD5 / SHA-1 / SHA-256 / SHA-512)

## v1.20.0 (2026-05-22)

### Feat

- add JWT decoder tool

## v1.19.0 (2026-05-22)

### Feat

- Base64 image preview + byte-delta at canvas width (Direction B phase 7)
- bps pinned-baseline delta at canvas width (Direction B phase 7)
- Timestamp UTC/Local toggle + Now/Start-of-day keys at canvas width (Direction B phase 7)
- Number Base interactive bit-grid at canvas width (Direction B phase 7)
- Cron 7-day fire strip at canvas width (Direction B phase 7)
- List inline count + Diff-with action at canvas width (Direction B phase 7)
- Diff dual-pane default at canvas width (Direction B phase 7)
- JSON two-pane layout at canvas width (Direction B phase 7)
- QR big preview + inline ECC/size controls (Direction B phase 7)
- Color session palette strip (Direction B phase 7)
- Bytes hexdump view + Latin-1/UTF-16LE decode (Direction B phase 7)
- Math visible tape unlock + canvas width-gate helper (Direction B phase 7)
- remaining canvas link pairs — Number/Math, Timestamp/Math, List/Diff, Color (Direction B phase 6)
- pipe-drag pipeline — typed in-canvas drags (Direction B phase 4)

## v1.18.0 (2026-05-22)

### Feat

- wire flagship Base64↔JSON live link end-to-end (ADR 0001)
- canonical-hub link engine (ADR 0001) — model + controller API

## v1.17.0 (2026-05-22)

### Feat

- desktop multi-card canvas (Direction B) — canvas MVP (#73)

## v1.16.0 (2026-05-21)

### Feat

- add YAML / TOML conversion to the JSON tool

## v1.15.0 (2026-05-21)

### Feat

- **desktop**: bound the shell into a height-capped, bordered window
- **web**: move the desktop toggle into the iPhone frame
- **desktop**: cap and center the shell on wide displays
- **web**: render desktop view on wide web with a layout toggle
- **web**: add desktop shell, sidebar, and in-pane tool view
- **web**: add view-mode state and shell-layout resolver

## v1.14.0 (2026-05-20)

### Feat

- **diff**: scroll long diff lines horizontally

### Fix

- **detail**: ellipsize long tool names in the nav bar
- **tools**: shorten input placeholders to fit the field
- **a11y**: keep layouts within bounds at large Dynamic Type

## v1.13.0 (2026-05-20)

### Feat

- **diff**: add Diff tool — body, catalog entry, and icon
- **mq**: hide ToolActionBar paste button when no handler is bound
- **diff**: add Myers line/word diff parser

## v1.12.0 (2026-05-20)

### Feat

- **list**: add List tool with split/join UI
- **list**: add split/join list parser

### Fix

- **list**: thread actionBar through List tool after Magic Box merge
- **detect**: defer Math to List for bulleted/numbered input

## v1.11.0 (2026-05-16)

### Feat

- apply Magic Box design handoff (6 items in one PR)

### Fix

- **nav**: give tab bar vertical breathing room
- **nav**: add 10px top padding to tab bar icons

## v1.10.0 (2026-05-15)

### Feat

- add Math expression evaluator tool

## v1.9.0 (2026-05-13)

### Feat

- **brand**: add hammer+quill marketing render
- **web**: regenerate favicon + PWA icons + splash for hammer+quill
- **ios**: regenerate AppIcon + LaunchImage for hammer+quill
- **brand**: redesign monogram to bracketed hammer+quill
- **web**: v1.7.0 launch SEO metadata + PWA manifest

### Refactor

- **brand**: MqMonogram renders SVG asset instead of Text.rich

## v1.8.0 (2026-05-12)

### Feat

- **web**: brand icons, PWA splash, manifest + theme-color meta
- **ios**: regenerate AppIcon + LaunchImage from brand assets
- **splash**: Dart-side splash crossfade + MqMonogram/MqSplashScreen
- **brand**: add SVG mark sources + rasterization pipeline

## v1.7.0 (2026-05-10)

### Feat

- **routing**: shared ToolDetailRoute wrapper
- **home**: ToolGridCard editorial grid tile
- **home**: CompactPasteBar two-stage hero composer
- **input**: MqInput accepts external focus node
- **widgets**: add masthead, rule, reading block, wordmark, monogram
- **widgets**: refresh mq components with editorial tokens
- **widgets**: remap MqIcons to Lucide
- **theme**: density tokens, controller, and MqTokens wiring
- **theme**: editorial palette and Plex typography with WCAG extensions
- **theme**: bundle IBM Plex fonts and flutter_lucide dep

### Fix

- **home**: early-return _onHeroChange when unmounted
- **icons**: map flash + flashFill to distinct Lucide glyphs

### Refactor

- **home**: drop redundant recentIds, single-pass _sortCatalog
- **utils**: extract truncateWithEllipsis helper
- **home**: swap inline-expand grid for push-route card grid
- **widgets**: MqRecentsRow consumes SectionRule
- **theme**: collapse typography style builders
- **state**: use enum.name in DensityController persistence

### Perf

- **theme**: cache Listenable.merge and drop MqDensityScope

## v1.6.0 (2026-05-09)

### Feat

- **cron**: add Cron tool body and register in catalog
- **cron**: add POSIX 5-field and natural-language parsers

## v1.5.0 (2026-05-07)

### Feat

- **home**: auto-expand single match, recents row, grid preview, long-press copy
- **mq**: InlineToolCard header morph + MqRecentsRow
- **tools**: add OpenInFooter for cross-tool output piping
- **home**: rows act as chips; selecting one hides the rest
- **home**: chip toggle + persistent body; remove Search tab
- **input**: heuristic paste detection on MqInput via controller listener
- **search**: inline tool cards replace per-result push navigation
- **home**: inline tool cards replace per-tile push navigation
- **history**: dedupe consecutive same-tool same-input adds
- **ui**: add InlineToolCard, HistoryRecorder, SeedSource scaffolding

### Refactor

- consolidate recorder glue, fix layering, type-safe expanded id
- **catalog**: builder returns body widget; delete *_screen wrappers
- **tools**: extract embeddable bodies, wire HistoryRecorder

## v1.4.0 (2026-05-03)

### Feat

- **qr**: add QR code reader and generator

### Fix

- **qr**: dispose ui.Image after PNG encode to free native memory
- **qr**: share works on web by dropping dart:io File temp-write

## v1.3.0 (2026-05-03)

### Feat

- **bytes**: add Bytes utility tool

### Refactor

- **mq**: align MqEmptyHint API and migrate timestamp screen
- **mq**: extract MqEmptyHint, dedupe across detail screens

## v1.2.0 (2026-05-02)

### Feat

- **timestamp**: expand formats and add keyword picker UI

## v1.1.0 (2026-05-02)

### Feat

- **search**: empty state on no matches + clearance token
- **theme**: add MqLayout.tabBarClearance + MqColors.onTint
- **home**: redesign with hero paste + flat tool grid
- **screens**: add Home, Search, History, Settings + tab scaffold
- **screens**: add utility catalog and 6 detail screens
- **utils**: add number base, JSON, color, and bps parsers
- **widgets**: add Magic Box component primitives
- **state**: add theme, history, and favorites controllers
- **theme**: add Magic Box design tokens (colors, typography, metrics)
- setup pre-commit hooks and GitHub Actions CI/CD
- add encoding cards parsing hex & base64 encoding
- improve UI/UX with animations
- replace with iOS design
- add a timestmp converter app
- init from vscode extensions

### Fix

- **ci**: bump commitizen to 4.13.9 for action 0.27.1 compatibility
- **settings**: show live pubspec version + use clearance token
- **timestamp**: surface ambiguity badge in seconds/ms overlap range
- **lint**: adopt Dart 3 wildcard params and null-aware elements
- resolve GitHub Actions workflow issues

### Refactor

- **detail**: unify output header + empty-state copy
- **catalog**: normalize utility tints to literal hex
- **history**: tighten hand-rolled values via tokens
- **home**: use MqLayout.tabBarClearance for bottom padding
- rename Magic Box codename to Masquerade
- **widgets**: scale iPhone frame to viewport with 2x cap
- **widgets**: replace device_frame with hand-rolled iPhone frame
- **app**: wire Magic Box shell with iPhone frame across all routes
- **timestamp_display_card**: render via MBSurface and MBMonoCell
- **copy_util**: use Magic Box tokens for clipboard toast
- migrate Color.withOpacity to withValues
- clean up widgets and imports
