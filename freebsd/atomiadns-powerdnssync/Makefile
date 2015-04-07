# $FreeBSD$

PORTNAME=	atomiadns
PORTVERSION=	1.1.36
CATEGORIES=	dns
MASTER_SITES=	http://www.atomiadns.com/tarballs/
PKGNAMESUFFIX=	-powerdnssync
DISTNAME=	${PORTVERSION}

MAINTAINER=	jimmy@sigint.se
COMMENT=	Atomia DNS PowerDNS sync agent

LICENSE=	ISCL

USES=		perl5
USE_PERL5=	configure
DEFAULT_MYSQL_VER=55
WRKSRC=		${WRKDIR}/${PORTNAME}-${PORTVERSION}/powerdns_sync

RUN_DEPENDS	+=	p5-Config-General>=0:${PORTSDIR}/devel/p5-Config-General
RUN_DEPENDS	+=	p5-Proc-Daemon>=0:${PORTSDIR}/devel/p5-Proc-Daemon
RUN_DEPENDS	+=	p5-SOAP-Lite>=0.710.08:${PORTSDIR}/net/p5-SOAP-Lite
RUN_DEPENDS	+=	p5-Moose>=0.94:${PORTSDIR}/devel/p5-Moose
RUN_DEPENDS	+=	p5-Net-DNS-ZoneFile-Fast>=0:${PORTSDIR}/dns/p5-Net-DNS-ZoneFile-Fast
RUN_DEPENDS	+=	p5-Net-DNS>=0:${PORTSDIR}/dns/p5-Net-DNS
RUN_DEPENDS	+=	p5-MIME-Base32>=0:${PORTSDIR}/converters/p5-MIME-Base32
RUN_DEPENDS	+=	p5-DBD-mysql>=0:${PORTSDIR}/databases/p5-DBD-mysql

USE_RC_SUBR	+=	atomiapowerdnssync

post-install:
	${INSTALL_DATA} -d ${WRKSRC}/conf ${STAGEDIR}${PREFIX}/share/atomiadns/conf
	${INSTALL_DATA} ${WRKSRC}/conf/atomiadns.conf.atomiapowerdnssync ${STAGEDIR}${PREFIX}/share/atomiadns/conf/atomiadns.conf.atomiapowerdnssync
	${INSTALL_DATA} ${WRKSRC}/conf/pdns.conf ${STAGEDIR}${PREFIX}/share/atomiadns/conf/pdns.conf
	${INSTALL_DATA} -d ${WRKSRC}/schema ${STAGEDIR}${PREFIX}/share/atomiadns/schema
	${INSTALL_DATA} ${WRKSRC}/schema/powerdns.sql ${STAGEDIR}${PREFIX}/share/atomiadns/schema/powerdns.sql
	${INSTALL_SCRIPT} ${WRKSRC}/debian/atomiadns-powerdns-database.postinst ${STAGEDIR}${PREFIX}/bin/atomiadns-sync-powerdns-database
	PKG_PREFIX=${PREFIX} ${SH} ${PKGINSTALL} ${PKGNAME} POST-INSTALL

.include <bsd.port.mk>
