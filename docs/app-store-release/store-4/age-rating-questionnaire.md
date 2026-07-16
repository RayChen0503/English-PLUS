# STORE-4 Age Rating Questionnaire

Last verified against Apple documentation: 2026-07-16.

This is the answer sheet for App Store Connect. It describes the shipping
product, not an aspirational feature list. Recheck it if communication,
moderation, web access, or wellbeing features change.

Official references:

- https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating
- https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions

## In-app controls and capabilities

| App Store Connect item | Answer | Shipping evidence and review note |
| --- | --- | --- |
| Parental controls | No | English+ does not currently provide a guardian dashboard, time limit, or guardian-controlled feature restriction. |
| Age assurance | Yes | Public student registration includes a declared 13+ eligibility gate. It does not verify identity documents or collect an exact birth date. |
| Unrestricted web access | No | The app opens only fixed privacy and support links; users cannot enter a URL or browse arbitrary websites. |
| Advertising | No | No ad network, paid placement, ATT prompt, or advertising identifier is used. |
| Messaging and chat | Yes | Students can send question-scoped asynchronous support requests to authorized teachers and volunteers. It is not public chat. |
| User-generated content | Yes | Students, teachers and volunteers can submit private, class-scoped support content, and volunteers can upload qualification evidence. It is not a public feed; authenticated scope, content screening, report/block controls and administrator moderation apply. |
| Social media | No | There are no public profiles, follower graphs, public feeds, likes, or content discovery. |

## Content frequency

| Content descriptor | Answer | Reason |
| --- | --- | --- |
| Profanity or crude humor | None | The curated question bank and product copy do not contain it. User messages are private and scoped, not editorial content supplied by English+. |
| Horror or fear themes | None | Not present. |
| Alcohol, tobacco, or drug references | None | Not present in the release question bank or product flow. |
| Medical or treatment information | None | English+ does not diagnose, treat, or provide medical instructions. |
| Health or wellness topics | Infrequent | The four-question check-in and low-pressure emotional support touch on daily wellbeing but do not make medical claims. This conservative answer is preferable to understating the feature. |
| Mature or suggestive themes | None | Not present. |
| Sexual content or nudity | None | Not present. |
| Graphic sexual content or nudity | None | Not present. |
| Cartoon or fantasy violence | None | Not present. |
| Realistic violence | None | Not present. |
| Prolonged graphic or sadistic violence | None | Not present. |
| Guns or other weapons | None | Not present. |
| Simulated gambling | None | Not present. |
| Gambling | No | Not present. |
| Contests | None | No in-app contest or prize system. |
| Loot boxes | No | Not present. |

## Age category and override

- **Made for Kids:** Not Applicable. Do not select the Kids Category.
- **Recommended public product policy:** public self-registration is 13+;
  younger students use the implemented school- or guardian-managed path.
- **Recommended override:** 13+ if the final terms state a 13-year minimum.
  Apple requires an override when the product's stated minimum age is higher
  than the calculated rating.
- **Age Suitability URL:** leave blank for 1.0 unless a dedicated public page
  is published. Do not use the privacy-policy URL as a substitute.

## Pre-submission confirmation

- [x] Product owner has selected the 13+ public-account policy.
- [ ] Terms, onboarding copy, privacy policy, App Store metadata, and support
      responses all use the same age boundary.
- [ ] The live questionnaire records User-generated content as Yes and Messaging
      and chat as Yes, with the private class scope explained in Review Notes.
- [ ] The rating calculated by App Store Connect is recorded in the release log.
