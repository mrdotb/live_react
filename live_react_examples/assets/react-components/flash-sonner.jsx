import React, { useState } from "react";
import { Toaster, toast } from "sonner";

export function FlashSonner({ flash, pushEvent }) {
  if (flash.info) {
    toast.info(flash.info, {
      id: "info",
      duration: Infinity,
      richColors: true,
      closeButton: true,
      onDismiss: (t) => {
        pushEvent("lv:clear-flash", { key: "info" });
      },
    });
  }

  if (flash.error) {
    toast.error(flash.error, {
      id: "error",
      richColors: true,
      duration: Infinity,
      closeButton: true,
      onDismiss: (t) => {
        pushEvent("lv:clear-flash", { key: "error" });
      },
    });
  }

  return <Toaster />;
}
