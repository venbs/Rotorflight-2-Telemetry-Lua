![RF2T Cover](https://github.com/venbs/Rotorflight-2-Telemetry-Lua/assets/30721827/0d414210-10de-4447-8ba7-edd02a6df853)
简单的设置，就可以让你的遥控器获得酷炫的仪表盘界面

</br>**支持的设备**：任何128*64的LCD，且为OPENTX/EDGETX/FREEDOMTX

</br>**例如**：Radiomaster Boxer ,Radiomaster TX12, Jumper T20,TBS Tango 2等

</br>**支持的协议**：CRSF

**1.陀螺仪设置**
</br>1.1 在接收机页面打开遥测
</br>1.2 打开打开下方所有遥测类型的复选框
</br>1.3 将下列命令复制CLI中运行，记得save！

    set crsf_gps_heading_reuse = THROTTLE
    set crsf_flight_mode_reuse = GOV_ADJFUNC
    set crsf_gps_altitude_reuse = HEADSPEED
    set crsf_gps_ground_speed_reuse = ESC_TEMP
    set crsf_gps_sats_reuse = MCU_TEMP
    save

**2.安装脚本**
</br>2.1将lua文件复制到SD/SCRIPTS/TELEMETRY下
</br>2.2模型设置，最后一页Screen，添加类型为Script，并选择 rf2t
</br>2.3回到主界面，按下Telemetry按钮，完成！

![Info](https://github.com/venbs/Rotorflight-2-Telemetry-Lua/assets/30721827/f292b3da-cda4-4632-b859-f29121301319)
