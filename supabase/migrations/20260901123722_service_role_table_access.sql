-- Edge Functions use the service-role client for all trusted data access.
-- BYPASSRLS does not imply SQL table privileges, so grant the role the CRUD
-- privileges it needs while keeping the key server-side only.
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;

alter default privileges in schema public
  grant all privileges on tables to service_role;
alter default privileges in schema public
  grant all privileges on sequences to service_role;
