# STORE-4 App Store Metadata — Traditional Chinese

Values below are a release-ready draft. Items marked **owner confirmation** must
be confirmed in App Store Connect before submission.

## Shared app information

- Name：`English+`
- Subtitle：`AI 與真人接力的英文學習`
- Primary language：Traditional Chinese
- Primary category：Education
- Secondary category：None
- Kids Category：否
- Price：Free
- Ads：None
- In-App Purchases：None in version 1.0
- Availability：Taiwan（台灣）only（owner confirmation）
- Distribution：Public App Store（owner confirmation）
- Release：通過審核後手動發布（owner confirmation）
- Bundle ID：`com.englishplus`
- Copyright：`© 2026 English+`

## Promotional text

從每日狀態、分級練習到老師與志工接力，讓學生在答錯後仍知道下一步。

## Description

English+ 是一套結合個人化英文練習、AI 即時解析與真人接力支持的學習平台。學生可以不加入班級，直接完成每日任務與自由練習；加入老師建立的班級後，還能接收指定任務，並在卡題時把完整題目與作答情境送給老師或經審核、獲授權的志工。

學生每天可透過簡短狀態檢測設定可用時間、挑戰意願與偏好題型，系統再安排可完成的練習。題庫涵蓋單字、文法、填空、克漏字、閱讀、翻譯與情境對話，並以能力點、難度、錯題與熟練度組織複習。AI 只在學生送出答案後提供解析與加練建議，不會在作答前直接揭露答案。

老師可建立與管理班級、查看加入後的學習進度、依學生需要派發題組，並回覆學生主動送出的題目。志工需先提交資格證明並通過管理員審核，再取得特定班級授權；志工只能看到學生主動求助所需的題目脈絡，不會取得完整班級或個人紀錄。

English+ 使用 Firebase 進行登入與同步，AI 請求透過受驗證的 Cloudflare 後端代理送至模型服務，App 內不保存正式 AI 金鑰。平台提供檢舉、封鎖、帳號刪除、隱私選擇與診斷資料控制。

English+ 是英文學習與教學協作工具，不提供醫療診斷、心理治療或 24 小時緊急服務。

## Keywords

`英文學習,會考英文,英文題庫,錯題複習,AI解題,班級任務,教師派題,志工陪伴`

## URLs

- Support URL：`https://sites.google.com/view/englishplus-privacy/%E6%94%AF%E6%8F%B4%E8%88%87%E8%81%AF%E7%B5%A1`
- Privacy Policy URL：`https://sites.google.com/view/englishplus-privacy/%E9%9A%B1%E7%A7%81%E6%94%BF%E7%AD%96`
- Marketing URL：leave blank for 1.0 unless a public product page is created.

## App information answers

- Content Rights：English+ question wording is self-authored. The app also
  displays scoped user-provided support messages and volunteer evidence under
  the service rules. Select the answer confirming the developer has the
  necessary rights; retain the provenance manifest and moderation policy as evidence.
- Age Rating：answer the questionnaire truthfully for user-generated content and
  scoped asynchronous messaging. Do not override downward and do not select the
  Kids Category. Public student self-registration is 13+; under-13 students use
  a school- or guardian-managed account path.
- Export Compliance：the app uses standard HTTPS/TLS supplied by the OS and SDKs,
  with no proprietary or non-standard cryptography. `ITSAppUsesNonExemptEncryption`
  is `NO`; confirm the exemption answers in App Store Connect.
- Advertising Identifier：not used.
- Digital Services Act status：must be completed by the Account Holder according
  to the actual trader/non-trader status; do not guess in code or documentation.

## Screenshot plan

Use five or six clean production screenshots with fictional accounts only:

1. Daily check-in and generated mission.
2. Question feedback after submission with AI explanation.
3. Free-practice filters and leveled question groups.
4. Student question-specific human support thread.
5. Teacher class, assignment and student progress.
6. Approved volunteer relay within an authorized class.

Do not show real names, email addresses, evidence files, test/debug labels,
Firebase consoles, admin credentials or device status clutter.
