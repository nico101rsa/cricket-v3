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
      url: '',      // e.g. 'https://abcdefghijkl.supabase.co' (Supabase → Project settings → API)
      anonKey: '',  // the "anon public" key from the same page
    },
  });
});
