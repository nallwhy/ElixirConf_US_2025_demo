export default SubmitOnMetaEnter = {
  mounted() {
    this.onKeydown = (e) => {
      if ((e.ctrlkey || e.metaKey) && e.key === "Enter") {
        this.el.form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }))
      }
    }

    this.el.addEventListener("keydown", this.onKeydown)
  },
  destroyed() {
    this.el.removeEventListener("keydown", this.onKeydown);
  }
}
