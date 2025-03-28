
![Frame 49](https://github.com/user-attachments/assets/cc9ada79-5b0c-4d61-a51e-81d54b6c37bb)

简单的设置，就可以让你的遥控器获得酷炫的仪表盘界面，还附带了一个简易的飞行日志查看工具，方便记录你每一天的飞行！

</br>**支持的设备**：任何128*64的LCD，且为OPENTX/EDGETX/FREEDOMTX

</br>**例如**：Radiomaster Boxer ,Radiomaster TX12, Jumper T20等

</br>**支持的协议**：ELRS接收机，并且启用了2.1的ELRS自定义遥测！

**1.FBL Settings**
</br>1.1 在接收机页面打开遥测，并启用ELRS自定义遥测
</br>1.2 设置遥测比率与你的TX一致！
</br>1.3 将下列命令复制CLI中运行，记得save！
    
    set crsf_telemetry_mode = CUSTOM 
    set crsf_telemetry_sensors = 3,43,4,5,6,60,15,50,52,93,90,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    save

**2.install lua**
</br>2.1将lua文件复制到SD/SCRIPTS/TELEMETRY下
</br>2.2模型设置，最后一页Screen，添加类型为Script，并选择 rf2t
</br>2.3回到主界面，按下Telemetry按钮，完成！


**3.Feature**
</br>3.1查看当前的飞行遥测
</br>3.2飞行时间每增加1min时，将会自动报时
</br>3.3飞行结束后，拔出电池，会有本次飞行的数据结算面板
</br>3.4按下Menu按键，可以查看当日的飞行日志！

![image](https://github.com/user-attachments/assets/c402927b-0024-4636-92f2-84873b58f063)

