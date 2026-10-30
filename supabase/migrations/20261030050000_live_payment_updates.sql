-- Membership calendar dates use the gym's Vietnam timezone.
alter function public.approve_membership_renewal(uuid) set timezone to 'Asia/Ho_Chi_Minh';

-- Realtime respects the existing per-user RLS policies.
do $$
declare target text;
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    foreach target in array array['membership_renewal_requests','memberships','app_notifications'] loop
      if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=target) then
        execute format('alter publication supabase_realtime add table public.%I',target);
      end if;
    end loop;
  end if;
end $$;
