function [error_bit_all,error_symbol_all]=rs_16qam_coding()
sonCarrierNum_temp=176;
symbols_Per_Carrier=1000;%ÿ���ز���������/֡��
bits_Per_Symbol=1;%ÿ���ź�������
modulate_bit=4;%���ƽ���(ÿ�����ű�����)
IFFT_bin_length=2^ceil(log2(sonCarrierNum_temp));%FFT����
PrefixRatio=1/4;%���������OFDM���ݵı��� 1/6~1/4
pilot_Inter=1;%���뵼Ƶ���
% CP=PrefixRatio*IFFT_bin_length ;%ÿһ��OFDM������ӵ�ѭ��ǰ׺����Ϊ1/4*IFFT_bin_length
CP=25;
SNR=0:1:20; %�����dB
nn=15;
kk=11;
%-------------------------------��Դ����----------------------------------------------
inforSource=randi([0,1],1,sonCarrierNum_temp*symbols_Per_Carrier*bits_Per_Symbol);
%---------------------------�ŵ�����--------------------------------------------------
msg4_temp=reshape(inforSource,4,[])';
msg4=bi2de(msg4_temp,'left-msb');%��ԭ��������ת��Ϊ4λ16����
msg4_togf=reshape(msg4,kk,[]).'; %��ת���ľ���ʮһ����
msgGF=gf(msg4_togf,4);%ת��Ϊ٤�޻���
msgrs=rsenc(msgGF,nn,kk); %(15,11��RS���� 11������ 15�����
msgrs1=reshape(msgrs.',1,length(msg4)/kk*nn);%��rs�������ת��һ��
msgrs2=de2bi(double(msgrs1.x),'left-msb');%ʮ����ת������
source_coded_data_rs=reshape(msgrs2',1,length(msg4)/kk*nn*4);%�������ź� ���һ���źţ����ݣ�
%----------------------------����-----------------------------------------------------
data_temp1= reshape(source_coded_data_rs,modulate_bit,[])';   %��ÿ��2���ؽ��з��飬�����������
modulate_data=qammod(bi2de(data_temp1),2^(modulate_bit));%���һ������
%-------------------------���뵼Ƶ----------------------------------------------
modulate_data=reshape(modulate_data,60,[]);
[modulate_wide,modulate_length]=size(modulate_data);
modulate_data_temp=[modulate_data(1:30,:);zeros(1,modulate_length);modulate_data(31:60,:)];%��ԭ��������ݵ��м��0
h1=commsrc.pn('GenPoly', [1 0 0 0 0 1 1],'NumBitsOut',61*modulate_length,'InitialConditions',[0 0 0 0 0 1]);
pn_code_temp=generate(h1);
pn_code=2*pn_code_temp-1;
pn_code=reshape(pn_code,61,[]);
modulate_data_pn=zeros(61,2*modulate_length);
for i=1:modulate_length
    modulate_data_pn(:,(2*i-1))=modulate_data_temp(:,i);
    modulate_data_pn(:,2*i)=pn_code(:,i);
end
modulate_data_pn(62:64,:)=0;
modulate_data_pn_out=[modulate_data_pn(31:64,:);modulate_data_pn(1:30,:)];
%-----------------------------------ifft-------------------------------------
time_signal_ifft=ifft(modulate_data_pn_out);
%-----------------------------------cp---------------------------------------
time_signal_cp=[time_signal_ifft(39:64,:);time_signal_ifft(1:64,:)];%��ifft��ĩβCP�������䵽��ǰ��
[time_signal_cp_wide,time_signal_cp_length]=size(time_signal_cp);
%-------------------------------------�����任-------------------------------------
for ii=1:modulate_length
    time_signal_out(:,ii)=[time_signal_cp(:,2*ii-1);time_signal_cp(:,2*ii)];
end
time_signal_out_1=reshape(time_signal_out,[],1);
for a=1:21
% -----------------------------------�ŵ�----------------------------------------
% chan=comm.RayleighChannel('SampleRate',550000, ...
%     'PathDelays',[0 2e-6],'AveragePathGains',[0 -3],'MaximumDopplerShift',100,'RandomStream','mt19937ar with seed','Seed',8007);
chan=comm.RayleighChannel('SampleRate',550000, ...
    'PathDelays',[0 2e-6],'AveragePathGains',[0 -3],'MaximumDopplerShift',100);
Rayleigh_signal=chan(time_signal_out_1);
awgn_signal=awgn( Rayleigh_signal,a-1,'measured');%��Ӹ�˹������
%   awgn_signal=time_signal_out_1;
%------------------------------------����ת��----------------------------------
   receive_signal_serial=awgn_signal;
   receive_signal_perallel=reshape(receive_signal_serial,time_signal_cp_wide,[]);
%------------------------------------ȥѭ��ǰ׺---------------------------------
   receive_data=receive_signal_perallel(27:90,:);
%-----------------------------------fft---------------------------------------
frequency_data_no_cp=fft(receive_data);
frequency_data=[frequency_data_no_cp(35:64,:);frequency_data_no_cp(1:31,:)];
[frequency_data_wide,frequency_data_length]=size(frequency_data);
%---------------------------------�ŵ�����----------------------------------------
channel_condition=zeros(frequency_data_wide,modulate_length);
estimate_data=zeros(frequency_data_wide,modulate_length);
for iii=1:modulate_length
    channel_condition(:,iii)=frequency_data(:,2*iii)./pn_code(:,iii);
    estimate_data(:,iii)=frequency_data(:,(2*iii-1))./channel_condition(:,iii);
end
real_data_temp=[estimate_data(1:30,:);estimate_data(32:61,:)];
%---------------------------------------���-----------------------------------------
demodulate_data_temp=reshape(real_data_temp,1,[]);
demodulate_data=qamdemod(demodulate_data_temp,2^(modulate_bit));
demodulate_data_bits_temp=reshape(demodulate_data,[],1);
demodulate_data_bits=de2bi(demodulate_data_bits_temp);
real_data_temp1 = reshape(demodulate_data_bits',1,[]);
%--------------------------------------------����-------------------------------------
[real_data_temp1_wide,real_data_length]=size(real_data_temp1);
yrsgs4=reshape(real_data_temp1 ,4,real_data_temp1_wide*real_data_length/4).';
yrsgs41=bi2de(yrsgs4,'left-msb');
yrsgs41=reshape(yrsgs41,nn,length(yrsgs41)/nn).';
ygsrsdecode=rsdec(gf(yrsgs41,4),nn,kk);
d1=reshape(ygsrsdecode.x',1,[]);
d2=de2bi(d1,'left-msb').';
rx_decode=reshape(d2,1,[]);
%-----------------------------------------------������----------------------------------
[error_num,error_ratio]=biterr(inforSource,rx_decode);
error_bit_all(a,1)=error_ratio;
%------------------------------------------------�������--------------------------------
error_symbol_data1= reshape(rx_decode,modulate_bit,[])';   %��ÿ��2���ؽ��з��飬�����������
error_symbol_data_receive=bi2de(error_symbol_data1);
error_symbol_data2= reshape(inforSource,modulate_bit,[])';   %��ÿ��2���ؽ��з��飬�����������
error_symbol_data_transmite=bi2de(error_symbol_data2);%���һ������
[error_symbol_num,error_symbol_ratio]=symerr(error_symbol_data_receive,error_symbol_data_transmite);
error_symbol_all(a,1)=error_symbol_ratio;
end
end

