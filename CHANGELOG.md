## v1.25.2 (2026-06-19)

### Fix

- **deps**: pin flutter_native_splash to ^2.4.7 for SDK compatibility

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
