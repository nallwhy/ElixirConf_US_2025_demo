// https://github.com/nallwhy/phoenix_live_view/blob/fc18aa656a4f95fea015b83673bd6ae3b4c1e9dc/assets/js/phoenix_live_view/view_hook.js#L88
const pushEvent = (entry, event, payload) => {
  entry.view.withinTargets(entry.fileEl, (view, targetCtx) => {
    entry.view.pushHookEvent(entry.fileEl, targetCtx, event, payload, () => { })
  })
}

export default function (entries, onViewError) {
  entries.forEach(entry => {
    const { file, meta: { upload_url, uuid } } = entry

    const xhr = new XMLHttpRequest()
    xhr.onload = () => {
      if (xhr.status === 200) {
        entry.progress(100)

        const { file: { displayName, mimeType, uri } } = JSON.parse(xhr.responseText)

        pushEvent(entry, "file-uploaded", { file_url: uri, filename: displayName, mime_type: mimeType, uuid })

      } else {
        pushEvent(entry, "file-upload-failed", { error: xhr.responseText })
        entry.error()
      }
    }
    xhr.onerror = () => {
      pushEvent(entry, "file-upload-failed", { error: xhr.responseText })
      entry.error()
    }
    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100)
        if (percent < 100) { entry.progress(percent) }
      }
    })

    onViewError(() => xhr.abort())

    xhr.open("POST", upload_url, true)

    xhr.setRequestHeader("X-Goog-Upload-Offset", "0")
    xhr.setRequestHeader("X-Goog-Upload-Command", "upload, finalize")

    xhr.send(entry.file)
  })
}
