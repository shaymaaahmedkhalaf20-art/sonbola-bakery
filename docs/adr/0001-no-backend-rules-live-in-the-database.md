# No backend server: the browser talks to Supabase, and the database enforces every rule

The public site and the admin dashboard are plain HTML and JavaScript served as static files by Cloudflare Pages, and both talk to Supabase directly with the publishable key. There is no server or framework of our own. Because the browser can't be trusted, every rule lives in the database: row-level security decides who can read or write each table, visitors can't write to the orders tables at all, and the only way to place an Order is a database function that looks up current prices, checks Opening Hours, Ordering Paused, Unavailable Products, Quantity Steps and the Open Order limit, adds the Delivery Fee and computes the total itself. The new-order email is sent from the database itself: `place_order` queues a call to Resend with `pg_net`, which runs only after the Order is saved, so a failed email never loses an Order. The Resend key lives in Supabase Vault.

We chose this over a framework such as Next.js or Astro with its own server code because the site is small, is edited mostly by one person, and already deploys as static files with no build step. We chose `pg_net` over a Supabase Edge Function for the email so that every backend change is plain SQL run in the SQL Editor, with no CLI or separate deploy.

## Consequences

- Never compute a price, total or status in the browser and send it to the database. The browser sends only Product ids and quantities.
- Never give visitors (`anon`) read access to orders or messages, and never put the service-role key in any HTML file. Anything in the browser is public.
- A new rule means a change to the SQL (policies or the order function), not just to the page's JavaScript.
