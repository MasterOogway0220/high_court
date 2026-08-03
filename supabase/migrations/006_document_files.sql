-- ─────────────────────────────────────────────────────────── document files
--
-- 001 gave document_versions a file_path but nothing to point it at. This adds the
-- bucket and the policies that guard it.
--
-- Uploads go browser → Supabase Storage directly, never through the Next.js server:
-- Vercel caps a request body at ~4.5 MB and PRD 3.6 asks for 25 MB. The bucket is
-- private; files are served as short-lived signed URLs.

insert into storage.buckets (id, name, public, file_size_limit)
values ('documents', 'documents', false, 26214400) -- 25 MB, PRD 3.6
on conflict (id) do update
  set public = false,
      file_size_limit = 26214400;

-- Permission on a file is the permission on the document that points at it, so the
-- storage policy asks the same question the table policy does — sees(visibility) —
-- rather than keeping a second copy of the rule that could drift.

drop policy if exists doc_files_read on storage.objects;
create policy doc_files_read on storage.objects for select to authenticated
using (
  bucket_id = 'documents'
  and exists (
    select 1
    from document_versions v
    join documents d on d.id = v.document_id
    where v.file_path = storage.objects.name
      and sees(d.visibility)
      and (d.deleted_at is null or is_staff())
  )
);

-- Whoever may write a document row may upload its file. The row insert is still
-- checked separately by docs_write, so an orphan object is the worst a stray upload
-- can produce.

drop policy if exists doc_files_write on storage.objects;
create policy doc_files_write on storage.objects for insert to authenticated
with check (bucket_id = 'documents' and (is_staff() or can_publish()));

-- The uploader cleans up its own object when the row insert fails; staff can clear
-- anything left behind.
drop policy if exists doc_files_delete on storage.objects;
create policy doc_files_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'documents'
  and (is_staff() or owner_id = auth.uid()::text)
);
