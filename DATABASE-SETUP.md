# LSPD Nightwatch — database activation

The main Detectives website now uses Supabase Auth and the shared Nightwatch database tables. Run the database setup once before officers sign in.

## 1. Apply the database schema

1. Open the Supabase project: https://supabase.com/dashboard/project/yxnzhhlribtiqhtqfoky
2. Open **SQL Editor**.
3. Open the repository file `supabase-schema.sql`.
4. Copy the entire file into a new SQL query and click **Run**.
5. Confirm the query completes successfully.

This creates:
- `nightwatch_profiles` — shared detective directory
- `nightwatch_records` — shared reports, warrants, intelligence, and case records
- `nightwatch_record_members` — per-investigation access list

The existing legacy tables are not deleted or modified.

## 2. Issue officer accounts

In Supabase, open **Authentication → Settings** (or **Sign In / Providers**, depending on the dashboard layout) and turn off **Allow new users to sign up**. Then open **Authentication → Users → Add user / Invite user** and issue an account to each detective. The database trigger automatically creates that officer's directory profile when the Auth user is created.

Officers sign in on the main Nightwatch website with their issued email and password.

## 3. Configure the site URL

In **Authentication → URL Configuration**, set the Site URL to:

`https://lspd-government.github.io/LSPD-Nightwatch/`

Add that same address to the allowed redirect URLs if Supabase requires it for your project.

## Access rules

- Signed-in officers can view shared cases, warrants, suspects, gang intelligence, and general intelligence reports.
- RICO and corruption records are visible only to the creator and officers added to that specific record.
- The creator can add or remove investigators. Added investigators can view and update the investigation, but cannot manage its membership or delete it.
- All detective profiles are visible to signed-in officers so investigators can be selected for a case.
- Anonymous visitors cannot read records. Row Level Security enforces the restrictions in the database.

## Important

Do not put a Supabase service-role key in this website. The client uses the project's publishable key; the SQL policies are what protect the records. Do not store real-world sensitive personal information or evidence in this roleplay portal.
