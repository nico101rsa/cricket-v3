// Build-time configuration. Commit your own values here so every device gets
// them; anything left blank can be typed into More → Cloud save on the phone.
// The Supabase anon key is meant to be public: the SQL in supabase/schema.sql
// makes the save table unreachable except through the two functions, and
// those need the sync code's hash.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}));
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket) {
  return (Cricket.config = {
    cloud: {
      url: 'https://uqhqvavhhgrrcqcfwowy.supabase.co', // Nico's "cricket-sim" project (Supabase → Project settings → API)
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxaHF2YXZoaGdycmNxY2Z3b3d5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxOTA2MjUsImV4cCI6MjEwNDc2NjYyNX0.77aQCp5YgMASfZvWiGMy3neQ2gGI9yQk5JuUjqazuS8', // the "anon public" key (public by design: the table is only reachable through the two functions, and those need a sync code's hash)
    },
  });
});
