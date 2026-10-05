-- ════════════════════════════════════════════════════════════════════
-- Zyps PostPilot — migration 006: coupons in Supabase
-- Run after 000–005. Safe to run more than once.
--
-- Coupons used to live only on the server's disk: Render wipes it on every
-- deploy, and each restart re-created the built-in coupons with a use count
-- of 0, so "max uses" never held. Coupons made in the admin page (/admin)
-- are stored here; increment_coupon_use() counts a use atomically.
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS coupons (
    code          TEXT PRIMARY KEY CHECK (code = upper(code) AND length(code) BETWEEN 3 AND 30),
    type          TEXT NOT NULL CHECK (type IN ('percent', 'flat', 'free_months')),
    value         INTEGER NOT NULL CHECK (value > 0),
    max_uses      INTEGER NOT NULL DEFAULT 0 CHECK (max_uses >= 0),   -- 0 = unlimited
    used_count    INTEGER NOT NULL DEFAULT 0,
    expires_on    TEXT DEFAULT '',                                    -- YYYY-MM-DD, '' = never
    plans_allowed TEXT DEFAULT '[]',                                  -- JSON list, [] = all plans
    description   TEXT DEFAULT '',
    created_at    TEXT,
    active        BOOLEAN NOT NULL DEFAULT true
);

CREATE OR REPLACE FUNCTION increment_coupon_use(p_code TEXT)
RETURNS SETOF coupons
LANGUAGE sql
SECURITY INVOKER
AS $$
    UPDATE coupons SET used_count = used_count + 1 WHERE code = upper(p_code) RETURNING *;
$$;

-- Only the server (service role key) may read or change coupons
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role only" ON public.coupons;
CREATE POLICY "service role only" ON public.coupons
    FOR ALL TO service_role USING (true) WITH CHECK (true);
REVOKE ALL ON TABLE public.coupons FROM anon, authenticated;
REVOKE ALL ON FUNCTION increment_coupon_use(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION increment_coupon_use(TEXT) TO service_role;

NOTIFY pgrst, 'reload schema';
