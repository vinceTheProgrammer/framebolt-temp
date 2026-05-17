use android_activity::AndroidApp;
use jni::objects::{JObject, JValue, JClass};
use jni::JNIEnv;
use jni::sys::jobject;
use jni::JavaVM;

use std::sync::Arc;

#[derive(Clone)]
pub struct AndroidContext {
    app: Arc<AndroidApp>,
}

impl AndroidContext {
    pub fn new(app: &AndroidApp) -> Self {
        Self { app: Arc::new(app.clone()) }
    }


    fn with_env<F>(&self, f: F)
    where
        F: FnOnce(&mut JNIEnv, JObject),
    {
        unsafe {
            let vm = JavaVM::from_raw(self.app.vm_as_ptr() as *mut _).unwrap();
            let mut env = vm.attach_current_thread().unwrap();
            let activity = JObject::from_raw(self.app.activity_as_ptr() as jobject);
            f(&mut env, activity);
        }
    }
}