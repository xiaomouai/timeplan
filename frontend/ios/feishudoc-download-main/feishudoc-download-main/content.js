let isExtracting = false;
let floatBtn = null;

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'PROCESS_DOCUMENT' && message.url) {
        setupExtractionUI(message.url);
    }
});

function setupExtractionUI(jsonUrl) {
    if (document.getElementById('feishu-pdf-downloader-wrapper')) return;

    const wrapper = document.createElement('div');
    wrapper.id = 'feishu-pdf-downloader-wrapper';

    floatBtn = document.createElement('div');
    floatBtn.id = 'feishu-pdf-downloader-btn';
    floatBtn.innerText = '下载 PDF';
    floatBtn.className = 'fdd-btn';

    // Create Dropdown Menu
    const dropdown = document.createElement('div');
    dropdown.className = 'fdd-dropdown-menu';

    const imgModeBtn = document.createElement('div');
    imgModeBtn.className = 'fdd-dropdown-item';
    imgModeBtn.innerText = '图片型';
    imgModeBtn.onclick = (e) => {
        if (isExtracting || hasDragged) return;
        e.stopPropagation();
        startExtraction(jsonUrl, 'image');
    };

    const textModeBtn = document.createElement('div');
    textModeBtn.className = 'fdd-dropdown-item';
    textModeBtn.innerText = '文字型';
    textModeBtn.onclick = (e) => {
        if (isExtracting || hasDragged) return;
        e.stopPropagation();
        startExtraction(jsonUrl, 'text');
    };

    dropdown.appendChild(imgModeBtn);
    dropdown.appendChild(textModeBtn);
    wrapper.appendChild(dropdown);
    wrapper.appendChild(floatBtn);
    document.body.appendChild(wrapper);

    // 增加拖动逻辑
    let isDragging = false;
    let hasDragged = false;
    let currentX;
    let currentY;
    let initialX;
    let initialY;
    let xOffset = 0;
    let yOffset = 0;

    wrapper.addEventListener("mousedown", dragStart);
    document.addEventListener("mouseup", dragEnd);
    document.addEventListener("mousemove", drag);

    function dragStart(e) {
        // Prevent dragging if clicking on dropdown items
        if (e.target.classList.contains('fdd-dropdown-item')) return;

        initialX = e.clientX - xOffset;
        initialY = e.clientY - yOffset;

        if (wrapper.contains(e.target)) {
            isDragging = true;
            hasDragged = false;
        }
    }

    function dragEnd(e) {
        initialX = currentX;
        initialY = currentY;
        isDragging = false;
        setTimeout(() => { hasDragged = false; }, 0);
    }

    function drag(e) {
        if (isDragging) {
            e.preventDefault();
            currentX = e.clientX - initialX;
            currentY = e.clientY - initialY;
            xOffset = currentX;
            yOffset = currentY;

            if (Math.abs(currentX) > 3 || Math.abs(currentY) > 3) {
                hasDragged = true;
            }
            wrapper.style.transform = `translate3d(${currentX}px, ${currentY}px, 0)`;
        }
    }
}

function updateProgress(text) {
    if (floatBtn) {
        floatBtn.innerText = text;
    }
}

async function startExtraction(jsonUrl, mode) {
    isExtracting = true;
    updateProgress('正在初始化...');
    floatBtn.classList.add('fdd-btn-active');

    try {
        // Fetch the json holding the page info (skip interception by adding _ext=1)
        const fetchUrl = jsonUrl.includes('?') ? jsonUrl + '&_ext=1' : jsonUrl + '?_ext=1';
        const res = await fetch(fetchUrl);
        const data = await res.json();

        let pageObj = data.data?.page || data.page;
        if (!pageObj) {
            if (data.link && data.page) pageObj = data.page;
        }

        let totalPages = 0;
        if (pageObj) {
            totalPages = Object.keys(pageObj).length;
        }

        if (totalPages === 0) {
            updateProgress('未找到页面数据');
            setTimeout(resetUI, 3000);
            return;
        }

        if (mode === 'text') {
            await extractTextMode(jsonUrl);
            return;
        }

        // Make sure jsPDF is loaded correctly
        if (!window.jspdf || !window.jspdf.jsPDF) {
            throw new Error("jsPDF library is not loaded properly.");
        }

        const { jsPDF } = window.jspdf;
        let pdf = null;

        for (let i = 0; i < totalPages; i++) {
            updateProgress(`正在获取第 ${i + 1}/${totalPages} 页...`);

            // Construct image URL
            let imgUrl = jsonUrl.replace('sub_id=txt_all.json', `sub_id=img_${i}.webp`);
            imgUrl = imgUrl.includes('?') ? imgUrl + '&_ext=1' : imgUrl + '?_ext=1';

            const imgRes = await fetch(imgUrl);
            if (!imgRes.ok) {
                console.warn(`Failed to fetch page ${i}`);
                continue;
            }
            const blob = await imgRes.blob();

            updateProgress(`组装第 ${i + 1}/${totalPages} 页...`);

            const imgObj = await createImageObject(blob);
            const base64Img = convertImageToBase64(imgObj);

            if (i === 0) {
                // Initialize PDF with the dimensions of the first page
                pdf = new jsPDF({
                    orientation: imgObj.width > imgObj.height ? 'landscape' : 'portrait',
                    unit: 'px',
                    format: [imgObj.width, imgObj.height]
                });
            } else {
                pdf.addPage([imgObj.width, imgObj.height], imgObj.width > imgObj.height ? 'landscape' : 'portrait');
            }

            // Add image. Format can be specified, since convertImageToBase64 forces image/png, we specify PNG.
            pdf.addImage(base64Img, 'PNG', 0, 0, imgObj.width, imgObj.height);
        }

        updateProgress('准备下载...');

        let title = '';
        const metaTitle = document.querySelector('meta[property="og:title"]');
        if (metaTitle && metaTitle.content) {
            title = metaTitle.content.trim();
        } else {
            title = document.title || 'feishu_document';
            // 移除前面可能出现的大量下划线
            title = title.replace(/^_+/g, '').trim();
            // 移除尾部固定的飞书后缀
            title = title.replace(/\s*-\s*飞书云文档$/, '').trim();
        }

        // 防止由于重复添加 .pdf 导致文件名难看
        if (!title.toLowerCase().endsWith('.pdf')) {
            title += '.pdf';
        }

        pdf.save(title);

        updateProgress('下载成功！');
    } catch (e) {
        console.error("Downloader Error: ", e);
        updateProgress('出现错误，请检查控制台');
    } finally {
        if (mode !== 'text') {
            setTimeout(resetUI, 3000);
        }
    }
}

async function extractTextMode(jsonUrl) {
    updateProgress('正在提取底层坐标和原图...');
    try {
        const fetchUrl = jsonUrl.includes('?') ? jsonUrl + '&_ext=1' : jsonUrl + '?_ext=1';
        const res = await fetch(fetchUrl);
        const data = await res.json();
        
        let pageObj = data.data?.page || data.page;
        if (!pageObj) {
            if (data.link && data.page) pageObj = data.page;
        }

        let totalPages = Object.keys(pageObj || {}).length;
        if (totalPages === 0) {
            updateProgress('未找到页面数据');
            setTimeout(resetUI, 3000);
            return;
        }

        let printFrame = document.getElementById('fdd-print-frame');
        if (printFrame) document.body.removeChild(printFrame);
        printFrame = document.createElement('iframe');
        printFrame.id = 'fdd-print-frame';
        printFrame.style.position = 'fixed';
        printFrame.style.right = '-9999px';
        printFrame.style.bottom = '-9999px';
        printFrame.style.width = '210mm'; 
        printFrame.style.height = '297mm';
        document.body.appendChild(printFrame);

        let doc = printFrame.contentWindow.document;
        doc.open();
        
        let title = '';
        const metaTitle = document.querySelector('meta[property="og:title"]');
        if (metaTitle && metaTitle.content) {
            title = metaTitle.content.trim();
        } else {
            title = document.title || 'feishu_document';
            title = title.replace(/^_+/g, '').trim();
            title = title.replace(/\s*-\s*飞书云文档$/, '').trim();
        }

        doc.write(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>${title}</title>
                <style>
                    /* 标准 A4 纸张尺寸在物理打印上的精确映射 */
                    @page { size: A4 portrait; margin: 0; }
                    body { margin: 0; padding: 0; background: white; -webkit-print-color-adjust: exact; }
                    .fdd-page {
                        position: relative;
                        width: 595.27pt;
                        height: 841.89pt;
                        overflow: hidden;
                        page-break-after: always;
                    }
                    .fdd-img {
                        position: absolute;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100%;
                        z-index: 1;
                    }
                    .fdd-text {
                        position: absolute;
                        z-index: 2;
                        color: rgba(0, 0, 0, 0.01); /* 肉眼不可见但鼠标能选中复制 */
                        white-space: pre;
                        font-family: "Microsoft YaHei", "SimSun", sans-serif;
                        line-height: 1;
                        user-select: text;
                        transform-origin: left bottom;
                    }
                </style>
            </head>
            <body>
        `);
        
        // 渲染每一页
        for (let i = 0; i < totalPages; i++) {
            updateProgress(`正在精细拼装第 ${i + 1}/${totalPages} 页...`);
            
            let imgUrl = jsonUrl.replace('sub_id=txt_all.json', `sub_id=img_${i}.webp`);
            imgUrl = imgUrl.includes('?') ? imgUrl + '&_ext=1' : imgUrl + '?_ext=1';
            
            doc.write(`<div class="fdd-page">`);
            doc.write(`<img class="fdd-img" src="${imgUrl}" />`);
            
            let pageElements = pageObj[i] || [];
            for (let el of pageElements) {
                if (el.t && el.r && el.r.length === 4) {
                    let text = el.t.replace(/</g, "&lt;").replace(/>/g, "&gt;");
                    // 飞书接口中：r[0] = x(left), r[1] = y(bottom), r[2] = 宽度宽, r[3] = 高度
                    // 并且高度一般匹配字号 h
                    let fontSize = el.h || el.r[3] || 12; 
                    let left = el.r[0];
                    let bottom = el.r[1];
                    let width = el.r[2];
                    
                    doc.write(`<span class="fdd-text" style="left: ${left}pt; bottom: ${bottom}pt; font-size: ${fontSize}pt; width: ${width}pt;">${text}</span>`);
                }
            }
            doc.write(`</div>`);
        }
        
        doc.write(`</body></html>`);
        doc.close();
        
        updateProgress('装配完成，等待图片加载...');
        
        // 保证所有底图完整加载完毕，防止打印出来的 PDF 是白屏
        await new Promise((resolve) => {
            let imgs = doc.querySelectorAll('img');
            let loadedCount = 0;
            if (imgs.length === 0) resolve();
            imgs.forEach(img => {
                if (img.complete) {
                    loadedCount++;
                    if (loadedCount === imgs.length) resolve();
                } else {
                    img.onload = img.onerror = () => {
                        loadedCount++;
                        if (loadedCount === imgs.length) resolve();
                    };
                }
            });
        });

        updateProgress('请在弹出的系统对话框中点击保存');
        
        // 打印前临时替换父页面 document.title，浏览器会以此作为默认文件名
        const originalTitle = document.title;
        // 去掉末尾的 .pdf，避免文件名变成 xxx.pdf.pdf
        const printTitle = title.endsWith('.pdf') ? title.slice(0, -4) : title;
        document.title = printTitle;
        
        // 延迟触发唤起本地原生的打印转PDF对话框
        setTimeout(() => {
            printFrame.contentWindow.focus();
            printFrame.contentWindow.print();
            // 打印对话框弹出后恢复原标题
            setTimeout(() => {
                document.title = originalTitle;
            }, 1000);
            resetUI();
        }, 800);

    } catch (e) {
        console.error("Text Mode Extractor Error: ", e);
        updateProgress('提取出错，请查看控制台');
        setTimeout(resetUI, 3000);
    }
}

function resetUI() {
    isExtracting = false;
    if (floatBtn) {
        floatBtn.innerText = '下载 PDF';
        floatBtn.classList.remove('fdd-btn-active');
    }
}

function createImageObject(blob) {
    return new Promise((resolve, reject) => {
        const url = URL.createObjectURL(blob);
        const img = new Image();
        img.onload = () => {
            resolve(img);
            // We can revoke the object URL after image loads completely and its data is read
            URL.revokeObjectURL(url);
        };
        img.onerror = reject;
        img.src = url;
    });
}

function convertImageToBase64(img) {
    const canvas = document.createElement('canvas');
    canvas.width = img.width;
    canvas.height = img.height;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0);
    // Explicitly return a format supported well by jsPDF (PNG or JPEG)
    return canvas.toDataURL('image/png');
}
