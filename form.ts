// Plugins - Form

import logger from '../logger';
import { showToast } from './toast';

declare global {
	interface HTMLFormElement {
		uiObject: any | null;
	}
}

class UIForm {
	private el: HTMLFormElement;
	private actionUrl: string;
	private dataTrigger: string;
	private dataReplace: string;
	private replaceType: string;
	private canReset: boolean;

	constructor(el: HTMLFormElement) {
		this.el = el;
		this.el.uiObject = this;
		this.actionUrl = el.action;
		this.replaceType = 'inner';
		this.dataTrigger = el.getAttribute('data-form-trigger') ?? '';
		this.dataReplace = el.getAttribute('data-form-replace') ?? '';
		this.canReset = el.getAttribute('data-form-reset') !== 'no-reset';
		this.handle();
	}

	public handle() {
		this.el.addEventListener('submit', (ev: Event) => {
			ev.preventDefault();
			this.submit();
			return false;
		});
	}

	public clear() {
		this.el.reset();
	}

	public submit() {
		try {
			const data = new FormData(this.el);
			const hasFileUpload = Array.from(data.values()).some((value) => value instanceof File);

			const request: RequestInit = {
				method: 'post',
				cache: 'no-cache',
			};

			if (hasFileUpload) {
				request.body = data;
			} else {
				const json:any = {};
				data.forEach((value, key) => {
					json[key] = value;
				});
				request.headers = new Headers({
					'Content-Type': 'application/json',
					Accept: 'application/json',
				});
				request.body = JSON.stringify(json);
			}

			fetch(this.actionUrl, request)
				.then((response) => {
					if (response.ok) {
						return response.json();
					}
					return Promise.reject(new Error('Invalid response'));
				})
				.then((jsonResp) => {
					if (jsonResp && jsonResp.success) {
						if (this.canReset) {
							this.clear();
						}
						if (this.dataTrigger) {
							this.handleTriggerSuccess();
						}
						if (jsonResp.content && this.dataReplace) {
							this.handleReplace(jsonResp.content);
						}
						this.triggerEvent();
					} else if (jsonResp.error) {
						showToast(jsonResp.error, 'error');
					}
				})
				.catch((err) => {
					logger.error('Form Error', (err as Error).message);
				});
		} catch (err) {
			logger.error('Form Error', (err as Error).message);
		}
	}

	public setActionUrl(url: string) {
		this.actionUrl = url;
	}

	public setDataReplace(replaceId: string) {
		this.dataReplace = replaceId;
	}

	public setReplaceType(type: string) {
		this.replaceType = type;
	}

	private handleTriggerSuccess() {
		const info = this.dataTrigger.split('#');
		if (info[0] === 'modal-close' && info[1]) {
			window.uiModal.hideModal(info[1]);
		} else if (info[0] === 'auth-redirect') {
			window.location.href = '/';
		}
	}

	private handleReplace(content: string) {
		const contentId = `#${this.dataReplace}`;
		const cEl = document.querySelector(contentId);
		if (cEl) {
			if (this.replaceType === 'inner') {
				cEl.innerHTML = content;
			} else {
				cEl.outerHTML = content;
			}

			UIForm.initTriggers(contentId);
			window.uiModal.initTriggers(contentId);
		}
	}

	private triggerEvent() {
		const event = new CustomEvent('reload', {});
		this.el.dispatchEvent(event);
	}

	public static submit(formId: string) {
		const modalEl = document.querySelector(`.form#${formId}`) as (HTMLElement | null);
		if (modalEl && modalEl.uiObject) {
			modalEl.uiObject.submit();
		}
	}

	public static init() {
		document.querySelectorAll('form.form').forEach((el) => {
			new UIForm(el as HTMLFormElement); // eslint-disable-line
		});

		UIForm.initTriggers('body');
	}

	public static initTriggers(_parentSel: string) {
	}
}

declare global {
	interface Window {
		uiForm: typeof UIForm
	}
}

if (typeof window !== 'undefined') {
	window.uiForm = UIForm;
}

export default UIForm;
