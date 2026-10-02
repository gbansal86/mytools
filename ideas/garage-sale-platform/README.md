# Garage Sale Discovery Platform

**Status:** Product idea / MVP planning  
**Initial launch market:** Regina, Saskatchewan, Canada  
**Saved:** 2026-10-02

## Product concept

Build a garage-sale discovery platform focused on:

> **What garage sales are happening near me, and how can I efficiently visit them?**

The platform should work on desktop and mobile. Start with a responsive website/PWA, then add native Android and iPhone apps later if usage justifies them.

The primary object is a **sale/event**, not an individual item listing.

### Buyer flow

```text
Open app/site
    ↓
Use current location or search another area
    ↓
See nearby garage sales on Map / List / Photo views
    ↓
Filter and save/select interesting sales
    ↓
Export list or build optimized route
    ↓
Navigate to selected sales
```

### Seller flow

```text
Login
    ↓
Create sale
    ↓
Upload photos
    ↓
Set address / map point
    ↓
Set date and opening/closing time
    ↓
Choose categories
    ↓
Publish
    ↓
Share to Facebook / WhatsApp / Messenger / copy link
```

## Regina-first launch

Validate in **Regina, Saskatchewan** before expanding.

Initial geographic scope can include Regina and nearby communities such as:

- White City
- Emerald Park
- Pilot Butte
- Lumsden

The opportunity is that garage-sale information is fragmented across Facebook groups, Kijiji, local classifieds, community pages and dedicated garage-sale apps.

Positioning:

> **Find → collect → filter → organize → export → route → visit**

## Buyer features

### Discovery

- "Garage sales near me"
- Search another city/neighbourhood/postal code
- Radius: 1 / 5 / 10 / 25 / 50 km + custom
- Map view
- List view
- Photo/grid view
- "Search this map area"
- Distance from current location
- Live status: Open now / Opening soon / Later / Tomorrow / Weekend / Closed / Cancelled

### Date filters

- Today
- Tomorrow
- Saturday
- Sunday
- This weekend
- Next 7 days
- Custom range

### Categories

- Furniture
- Electronics
- Tools
- Toys
- Clothing
- Books
- Collectibles
- Appliances
- Bikes
- Automotive
- Antiques
- Garden/outdoor
- Free items
- Other

### Search examples

- `tools within 10 km`
- `kids bicycle this Saturday`
- `furniture near me`
- `estate sale electronics`

Search should cover title, description, categories, featured items and eventually AI-detected objects from photos.

### Saved lists

Examples:

- Saturday Route
- Furniture
- Tools
- Electronics
- For Mom
- Next Weekend

## Export system — major differentiator

Users should be able to export:

- All visible filtered results
- Selected sales
- Saved lists
- Planned routes

Formats:

- CSV
- XLSX/Excel
- PDF
- Printable list
- Shareable web list
- Calendar/ICS
- Google Maps route
- Other navigation links where practical

Suggested export columns:

```text
Sale Name
Address
Approximate/Exact Location
Distance
Date
Start Time
End Time
Status
Categories
Description
Featured Items
Photo Count
Source
Original Source Link
Map Link
Seller Notes
User Notes
```

Example workflow:

```text
Search Regina within 25 km
        ↓
127 results
        ↓
Filter Saturday + Tools + Electronics
        ↓
Select 15 sales
        ↓
Export to Excel/PDF
        ↓
Build optimized Saturday route
```

## Route planning

Users select sales and tap **Build My Route**.

Route logic can eventually consider:

- Starting location
- Distance
- Opening time
- Closing time
- Selected priorities
- Number of stops
- Approximate visit duration
- Return-home option

Later feature: **Garage Sales Along My Route**.

## Seller listing

Basic fields:

- Sale title
- Address / map point
- Start/end date
- Start/end time
- Description
- Categories
- Photos

Optional:

- Featured items
- Approximate prices
- Payment methods
- Rain or shine
- Indoor/outdoor
- Accessibility notes
- Parking notes

Sale types:

- Garage Sale
- Yard Sale
- Moving Sale
- Estate Sale
- Community Sale
- Multi-family Sale
- Church/School Sale
- Flea/Pop-up Sale

Statuses:

- Draft
- Scheduled
- Open
- Closed early
- Cancelled
- Finished

Listings should automatically expire after the event.

## Photos — MVP decision

**Do not implement user-owned photo storage yet.**

For the first version:

- Upload directly from phone or computer
- Support camera capture in mobile/PWA
- Compress and resize automatically
- Store optimized display images and thumbnails
- Remove EXIF/GPS metadata where appropriate
- Delete expired-sale media according to a retention policy

Google Drive/Google Photos/Dropbox/OneDrive storage can be reconsidered later only if there is a real need.

Sellers should be able to upload many photos without creating separate product listings.

Later AI may detect objects such as bicycles, drills, TVs, tables, lawn mowers, toys and books to improve search.

## Facebook integration — keep both options

Do not force Regina users to stop using Facebook Groups.

### Option A — create in our app first

```text
Create garage sale
      ↓
Publish to our platform
      ↓
Share
      ↓
Facebook / WhatsApp / Messenger / Copy Link
```

Generate a ready-to-share post containing title, date/time, general location, categories, preview and listing link.

### Option B — already posted on Facebook

Provide:

**I already posted this on Facebook**

Allow the seller to paste the Facebook post URL or use device sharing where supported. Build a draft from information the user supplies/imports and ask them to verify missing fields. Store the original source link when supplied.

### Facebook limitation

Do **not** base the MVP on automatically reading every post from arbitrary Facebook Groups. Meta discontinued the former Groups API capabilities third-party apps relied on for broad Group post access/publishing.

Use:

- User-assisted sharing
- User-assisted import
- Original Facebook links when provided
- No dependency on scraping arbitrary/private Groups

## Community garage sales

Support a parent event with many participating homes.

Example:

**Green Meadows Community Garage Sale**  
Saturday 8 AM–3 PM  
23 participating homes

Buyer options:

- View all homes on a map
- Select individual homes
- Add all to route
- Export the community-sale list

Useful for neighbourhoods, apartment complexes, schools, churches and community associations.

## Accounts

Browsing should **not require login**.

Require login for:

- Save sales
- Create alerts
- Save lists
- Export user-specific lists
- Contact sellers
- Post/manage a sale

Login options:

- Google
- Facebook
- Apple
- Email

## Notifications / Garage Sale Radar

Example alert:

```text
Area: Regina
Radius: 10 km
Categories: Tools + Electronics
Days: Saturday/Sunday
```

Potential notification:

> New garage sale 2.3 km away — tools, bicycles and electronics — Saturday 8 AM.

Other alerts:

- New matching sale
- Saved sale starts soon
- Sale cancelled
- Sale time changed
- Community sale added
- Weather-related seller update

## Privacy and safety

Because many sales occur at private homes:

- Approximate-location mode before sale
- Seller controls when exact address appears
- Option to reveal exact address shortly before opening
- Hide exact address after sale
- Remove unnecessary image metadata
- In-app contact instead of exposing email/phone by default
- Block/report controls
- Spam/duplicate detection
- Rate limiting
- Moderation tools
- Seller can cancel/close early

## PWA-first strategy

Do not build three separate products initially.

First release:

**Responsive website + Progressive Web App (PWA)**

One app should work on:

- Desktop
- Android
- iPhone
- Tablet

PWA capabilities where supported:

- Install to home screen
- GPS/location
- Camera/photo upload
- Full-screen mobile interface
- Saved state
- Notifications

Later add native Android/iPhone clients using the same backend/API.

## Low-cost architecture

### Frontend
- Next.js / React
- PWA
- MapLibre

### Backend
- Supabase/PostgreSQL initially
- OAuth authentication
- Serverless/API layer as needed

### Photos
- Cloudflare R2 or another low-cost object store
- Automatic resizing/compression

### Maps
- MapLibre
- OpenStreetMap data
- Use a suitable tile/geocoding provider for production rather than relying on unrestricted public OSM tile servers

### Search
Start with PostgreSQL search, then consider Meilisearch/Typesense or another geospatial/search service if needed.

### Export
Generate internally:
- CSV
- XLSX
- PDF
- ICS

No paid AI/API is required for the MVP.

## Cost target

Initial test target:

> **C$0–5/month infrastructure, plus domain**, while usage fits legitimate free tiers.

Possible early costs:

- Domain: approximately C$15–30/year depending on registrar/TLD
- Hosting/serverless: potentially free during MVP
- Database/auth: potentially free during MVP
- Low-volume photo storage: potentially free/very low cost
- Maps: development allowances may be free; production commercial usage may eventually require a paid tile/geocoding plan

If native apps are published later, app-store developer fees also apply.

**Verify all provider pricing immediately before launch because pricing and free-tier terms can change.**

## Competitors to study

- Yard Sale Treasure Map
- Garage Sale Map
- YardHo!
- LocalSale
- The Pickers Map
- TreasureHunt
- Yard Sale Companion
- EstateSales.NET
- Kijiji
- Facebook Marketplace / local Facebook Groups
- UsedRegina
- Treasure Trail
- Great Garage Sales

Common baseline features already exist elsewhere:

- Nearby map
- Photos
- Seller posting
- Filters
- Saved sales
- Route planning

Therefore differentiate through:

> **Discovery + structured data + bulk selection + export + planning + route management + desktop usefulness**

Working positioning:

> **The easiest way to discover, collect, organize, export and route garage sales around you.**

## Monetization

Do not charge for basic discovery or ordinary listings during launch.

### Buyer — free baseline
- Nearby search
- Map
- List/photos
- Filters
- Save sales
- Basic route
- CSV export

### Seller — free baseline
- Post sale
- Photos
- Normal map placement
- Share link

Possible paid options later:

- Featured sale
- Top-of-area/map promotion
- Weekend boost
- Professional estate-sale/business account
- Advanced analytics
- Advanced bulk export/planning
- Local business advertising

## MVP screens

1. Explore / Near Me
2. Map
3. List
4. Photo/Grid View
5. Sale Details
6. Create Sale
7. Edit/My Sales
8. Saved Sales
9. Saved Lists / Route Planner
10. Export
11. Login/Profile
12. Alerts
13. Admin/Moderation

## MVP phases

### Phase 1 — Regina proof of concept
- PWA/web
- Map + list
- Current location
- Regina area search
- Date/radius/category filters
- Seller posting
- Direct photo uploads
- Sale details
- Save sales
- CSV export
- Basic share link

### Phase 2 — Planning
- XLSX/PDF exports
- Saved lists
- Route builder
- Route optimization
- Calendar export
- Better live status

### Phase 3 — Growth
- Facebook-assisted import/share
- Notifications/radar
- Community sale events
- Seller analytics
- Moderation improvements

### Phase 4 — Advanced
- AI photo object detection
- Natural-language search
- Garage-sales-along-my-route
- Native Android/iPhone apps
- Professional seller plans

## Product principles

1. Near-me discovery first.
2. No login required just to browse.
3. Seller can publish quickly.
4. Photos are more important than detailed item entry.
5. Listings expire automatically.
6. Map, list and photo views are equally useful.
7. Export is a first-class feature.
8. Facebook complements the product; it is not a required backend dependency.
9. Privacy matters because listings may point to private homes.
10. Keep the Regina MVP extremely inexpensive.
11. Do not implement user-owned photo storage in the MVP.
12. Validate demand in Regina before expanding.

## Working product statement

> **Find every garage sale around you, see what is there, organize the ones you want, export the list, and build your route.**

Initial local message:

> **Regina Garage Sales — one map for the weekend.**
