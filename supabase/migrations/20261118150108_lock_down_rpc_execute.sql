-- Stop exposing functions that nothing should call over the API.
--
-- apply_streak() is a trigger function, so PostgREST publishing it at
-- /rest/v1/rpc/apply_streak is pure noise — Postgres would refuse the call
-- anyway ("can only be called as a trigger"). Revoke it so it isn't listed.
--
-- The rest are the app's real RPCs, but every one of them is meaningless
-- without auth.uid(), so anon has no business calling them.

revoke all on function public.apply_streak() from public, anon, authenticated;

revoke execute on function public.today_feed()                from anon;
revoke execute on function public.friends_list()               from anon;
revoke execute on function public.friend_requests()            from anon;
revoke execute on function public.search_users(text)           from anon;
revoke execute on function public.my_invite_code()             from anon;
revoke execute on function public.redeem_invite(text)          from anon;

grant execute on function public.today_feed()                  to authenticated;
grant execute on function public.friends_list()                to authenticated;
grant execute on function public.friend_requests()             to authenticated;
grant execute on function public.search_users(text)            to authenticated;
grant execute on function public.my_invite_code()              to authenticated;
grant execute on function public.redeem_invite(text)           to authenticated;
